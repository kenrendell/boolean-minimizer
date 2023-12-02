#!/usr/bin/env lua5.4

local qmc = require('lib.qmc')

local help_msg = table.concat({
	"Usage:",
	"  boolean-minimize [options] --input {num|char [chars...]} --{minterm|maxterm} [term [terms...]]\n",
	"Options:",
	"  --all                             := print all solutions to the Boolean function.",
	"  --verbose                         := show minimization process.",
	"  --sum-of-product                  := show all results in sum-of-products (SOP) form.",
	"  --product-of-sum                  := show all results in product-of-sums (POS) form.",
	"  --input {num|char [chars...]}     := number of inputs or variables in a Boolean function.",
	"  --minterm [term [terms...]]       := minterms of a Boolean function.",
	"  --maxterm [term [terms...]]       := maxterms of a Boolean function.",
	"  --optional-term [term [terms...]] := don't-care terms of a Boolean function."
}, "\n")

local symbols, terms, dc_terms = {}, {}, {}

local function print_error(msg, exit_code)
	if type(msg) == "table" then
		for i = 1, #msg do io.stderr:write(string.format("%s\n", msg[i])) end
	else io.stderr:write(string.format("%s\n", msg)) end
	if exit_code then os.exit(exit_code) end
end

local current_option, options = nil, {
	["all"] = {{}, false}, -- print all solutions to the Boolean function.
	["verbose"] = {{}, false}, -- show minimization process
	["sum-of-product"] = {{}, false}, -- show all results in sum-of-products (SOP) form.
	["product-of-sum"] = {{}, false}, -- show all results in product-of-sums (POS) form.
	["input"] = {{}, false}, -- number of inputs or variables in a Boolean function.
	["minterm"] = {{}, false}, -- minterms of a Boolean function.
	["maxterm"] = {{}, false}, -- maxterms of a Boolean function.
	["optional-term"] = {{}, false}, -- don't-care terms of a Boolean function.
}

-- Show help message when there is no provided arguments.
if #arg == 0 then print_error(help_msg, 1) end

-- Parse command-line arguments
for i = 1, #arg do
	local option = string.match(arg[i], "^%-%-(.+)$")
	if not option then
		if not current_option then print_error({"no option specified for the argument!", help_msg}, 1)
		end table.insert(options[current_option][1], arg[i])
	elseif not options[option] then print_error({string.format('option "%s" is invalid!', option), help_msg}, 1)
	else current_option, options[option][2] = option, true end
end

if options.all[2] and #options.all[1] > 0 then
	print_error([[option "all" doesn't accept any arguments!]], 1)
end

if options.verbose[2] and #options.verbose[1] > 0 then
	print_error([[option "verbose" doesn't accept any arguments!]], 1)
end

if options.minterm[2] and options.maxterm[2] then
	print_error([[both option "minterm" and "maxterm" are specified!]], 1)
end

if options["sum-of-product"][2] and options["product-of-sum"][2] then
	print_error([[both option "sum-of-product" and "product-of-sum" are specified!]], 1)
end

if options["sum-of-product"][2] and #options["sum-of-product"][1] > 0 then
	print_error([[option "sum-of-product" doesn't accept any arguments!]], 1)
end

if options["product-of-sum"][2] and #options["product-of-sum"][1] > 0 then
	print_error([[option "product-of-sum" doesn't accept any arguments!]], 1)
end

-- Initialize and validate input variables.
if options.input[2] then
	local n = #options.input[1]
	if n > 1 and n <= 26 then
		local chars = {}
		for i = 1, n do -- all characters are converted to uppercase.
			local char = options.input[1][i]:upper()
			local byte = char:sub(1, 1):byte()
			if #char ~= 1 or chars[char] or byte < 65 or byte > 90 then
				print_error('each argument in option "input" must be distinct and an alphabet character when there are multiple arguments!', 1)
			end table.insert(symbols, char)
			chars[char] = true
		end
	elseif n == 1 then
		local char = options.input[1][1]:upper()
		local input, byte = math.tointeger(options.input[1][1]), char:sub(1, 1):byte()
		if (not input and #char == 1 and (byte < 65 or byte > 90)) or (input and (input <= 0 or input > 26)) then
			print_error('option "input" must be an integer between 1 and 26 or an alphabet character when there is only one argument!', 1)
		end
		if input then -- Use uppercase alphabet characters when the input is an integer.
			for i = 1, input do table.insert(symbols, string.char(64 + i)) end
		else table.insert(symbols, char) end
	else print_error('option "input" accepts 1 to 26 arguments!', 1) end
else print_error('option "input" must be specified!', 1) end

-- If the terms are specified with option "minterm" while the
-- option "product-of-sum" is set, then convert all minterms (except don't-care terms)
-- to their corresponding maxterms to find the solution in product-of-sums (POS) form.
local maxterm = options["product-of-sum"][2] or (not options["sum-of-product"][2] and options.maxterm[2])

if options.minterm[2] or options.maxterm[2] then
	local term_type = (options.minterm[2] and "minterm") or "maxterm"
	local convert_term = (maxterm and options.minterm[2]) or (not maxterm and options.maxterm[2])
	local max_input, terms_set = (1 << #symbols) - 1, {}

	-- Initialize and validate terms
	for i = 1, #options[term_type][1] do
		local term = math.tointeger(options[term_type][1][i])
		if not term or term < 0 or term > max_input then
			print_error(string.format('option "%s" arguments must be an integer between 0 and %d!', term_type, max_input), 1)
		end
		if term and not terms_set[term] then
			if not convert_term then table.insert(terms, term) end
			terms_set[term] = true
		end
	end
	-- Initialize and validate don't-care terms.
	for i = 1, #options["optional-term"][1] do
		local dc_term = math.tointeger(options["optional-term"][1][i])
		if not dc_term or dc_term < 0 or dc_term > max_input then
			print_error(string.format('option "optional-term" arguments must be an integer between 0 and %d!', max_input), 1)
		end
		if dc_term and not terms_set[dc_term] then
			table.insert(dc_terms, dc_term)
			terms_set[dc_term] = true
		end
	end
	-- Convert terms from minterms to maxterms or vice versa.
	if convert_term then for i = 0, max_input do
		if not terms_set[i] then table.insert(terms, i) end
	end end table.sort(terms)
else print_error('either option "minterm" or "maxterm" must be specified!', 1) end

-- Print the resulting minimize boolean expression.
if #terms + #dc_terms == 1 << #symbols then io.stdout:write((maxterm and "0\n") or "1\n")
elseif #terms == 0 then io.stdout:write((maxterm and "1\n") or "0\n")
else if options.verbose[2] then qmc.verbose = true end
	-- Solve for the boolean expression using Quine-McCluskey method and Petrick's method.
	local prime_implicants = qmc.get_prime_implicants(terms, dc_terms, #symbols, maxterm)
	local covers = qmc.minimize_prime_implicants(prime_implicants, terms, #symbols, maxterm)

	if options.all[2] then -- print all solutions
		for _, complexity in ipairs(covers.complexity) do
			for _, cover in ipairs(covers[complexity]) do
				io.stdout:write(string.format("%s\n", qmc.get_symbolic_cover(cover, symbols, maxterm)))
			end
		end
	else -- print the solution with least complexity
		for _, cover in ipairs(covers[covers.complexity[1]]) do
			io.stdout:write(string.format("%s\n", qmc.get_symbolic_cover(cover, symbols, maxterm)))
		end
	end
end
