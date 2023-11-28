#!/usr/bin/env lua5.4

local M = {}

local function count_set_bits(n)
	local count = 0
	while n > 0 do
		n = n & (n - 1)
		count = count + 1
	end return count
end

function table.clone(t)
	local clone = {}
	for key, value in pairs(t) do
		clone[key] = value
	end return clone
end

-- Sort based on the complexity or the sum of the following:
-- >> number of NOT gates for each prime implicant in a cover.
-- >> number of inputs in AND/OR gate for each prime implicant in a cover.
-- >> number of inputs in AND/OR gate where the input represents a prime implicant in a cover.
local function sort_covers(covers)
	local sorted_covers = { complexity = {} }

	for cover in pairs(covers) do
		local complexity = (cover.n > 1 and cover.n) or 0
		local sorted_cover = { complexity = {} }

		for term in pairs(cover) do
			if term ~= 'n' then
				local term_complexity = term[3]
				complexity = complexity + term_complexity
				if not sorted_cover[term_complexity] then
					sorted_cover[term_complexity] = {}
					table.insert(sorted_cover.complexity, term_complexity)
				end table.insert(sorted_cover[term_complexity], term)
			end
		end table.sort(sorted_cover.complexity)

		if not sorted_covers[complexity] then
			sorted_covers[complexity] = {}
			table.insert(sorted_covers.complexity, complexity)
		end table.insert(sorted_covers[complexity], sorted_cover)
	end table.sort(sorted_covers.complexity)
	return sorted_covers
end

local function initialize_implicants(implicants, terms, n)
	local mask, set_bits = ~(-1 << n), 0
	for _, term in ipairs(terms) do
		set_bits = count_set_bits(term)
		if not implicants[set_bits] then
			implicants[set_bits] = {}
			implicants[set_bits][mask] = {}
			table.insert(implicants.set_bits, set_bits)
		end implicants[set_bits][mask][term] = false
	end table.sort(implicants.set_bits)
end

-- Create prime implicant chart
local function create_prime_implicant_chart(prime_implicants, terms)
	local prime_implicant_columns = {}
	for _, term in ipairs(terms) do
		local column = {}
		for _, prime_implicant in ipairs(prime_implicants) do
			if (term & prime_implicant[2]) == prime_implicant[1]
			then column[prime_implicant] = true end
		end table.insert(prime_implicant_columns, column)
	end return prime_implicant_columns
end

-- Quine McCluskey Algorithm
-- See https://en.wikipedia.org/wiki/Quine%E2%80%93McCluskey_algorithm
function M.get_prime_implicants(terms, dc_terms, n, maxterm)
	-- If maxterm = true, then the terms are maxterms.
	-- If maxterm = false, then the terms are minterms.

	local prime_implicants = {}
	local implicants = { set_bits = {} }

	-- Initialize implicants including the don't-care terms.
	initialize_implicants(implicants, terms, n)
	initialize_implicants(implicants, dc_terms, n)

	repeat
		local new_implicants = { set_bits = {} }
		local new_implicants_empty = true

		for _, set_bits in ipairs(implicants.set_bits) do
			for mask, implicant_terms in pairs(implicants[set_bits]) do
				for term in pairs(implicant_terms) do
					if implicants[set_bits + 1] and implicants[set_bits + 1][mask] then
						for adjacent_term in pairs(implicants[set_bits + 1][mask]) do
							local bit_change = (mask & term) ~ (mask & adjacent_term)
							if (bit_change & (~bit_change + 1)) == bit_change then -- check if there is one bit change (adjacent)
								local new_mask = mask ~ bit_change

								if not new_implicants[set_bits] then
									new_implicants[set_bits] = {}
									table.insert(new_implicants.set_bits, set_bits)
								end if not new_implicants[set_bits][new_mask] then new_implicants[set_bits][new_mask] = {} end

								-- Mark a check on adjacent terms
								implicants[set_bits][mask][term] = true
								implicants[set_bits + 1][mask][adjacent_term] = true

								new_implicants[set_bits][new_mask][term & new_mask] = false
								new_implicants_empty = false
							end
						end
					end
					-- Unchecked terms are considered prime implicant
					if not implicants[set_bits][mask][term] then
						local nvar = count_set_bits(mask) -- number of variables
						table.insert(prime_implicants, 1, {term, mask,
							-- Term complexity = (number of NOT gates) + (number of inputs in AND/OR gate)
							((maxterm and set_bits) or (nvar - set_bits)) + ((nvar > 1 and nvar) or 0)
						})
					end
				end
			end
		end implicants = new_implicants
	until new_implicants_empty

	return prime_implicants
end

-- Petrick's Algorithm
-- See https://en.wikipedia.org/wiki/Petrick%27s_method
-- Based on https://github.com/BinPy/BinPy/blob/develop/BinPy/algorithms/QuineMcCluskey.py
function M.minimize_prime_implicants(prime_implicants, terms)
	-- Create prime implicant chart/table
	local prime_implicant_columns = create_prime_implicant_chart(prime_implicants, terms)
	local covers = {} -- groups of prime implicants that will cover all the terms.

	-- Initialize covers
	for prime_implicant in pairs(prime_implicant_columns[1]) do
		covers[{[prime_implicant] = true, n = 1}] = true
	end

	-- Find all minimum solutions
	for i = 2, #prime_implicant_columns do
		local new_covers = {}
		for cover in pairs(covers) do
			for prime_implicant in pairs(prime_implicant_columns[i]) do
				local cover_clone, append = table.clone(cover), true

				-- Applying the boolean distributive law
				if not cover_clone[prime_implicant] then
					cover_clone[prime_implicant] = true
					cover_clone.n = cover_clone.n + 1
				end

				-- Applying the boolean absorption law
				for new_cover in pairs(new_covers) do
					local match = 0
					for c in pairs(cover_clone) do
						if c ~= 'n' and new_cover[c] then match = match + 1 end
					end
					if match == cover_clone.n then new_covers[new_cover] = nil
					elseif match == new_cover.n then append = false end
				end if append then new_covers[cover_clone] = true end
			end
		end covers = new_covers
	end

	return sort_covers(covers)
end

function M.get_symbolic_cover(cover, symbols, maxterm)
	local symbolic_cover = {}
	local separator_symbols = (maxterm and {'(', ')', '', ' + '}) or {'', '', ' + ', ''}
	local ncomp, nvar = #cover.complexity, #symbols

	for i = 1, ncomp do
		local prime_implicants = cover[cover.complexity[i]]
		local nterm = #prime_implicants

		for j = 1, nterm do
			local prime_implicant, start = prime_implicants[j], false
			table.insert(symbolic_cover, separator_symbols[1])
			for k = nvar - 1, 0, -1 do
				if (prime_implicant[2] >> k) & 1 == 1 then
					if start then table.insert(symbolic_cover, separator_symbols[4]) end
					table.insert(symbolic_cover, symbols[nvar - k])
					if ((prime_implicant[1] >> k) & 1 == 1) == maxterm then
						table.insert(symbolic_cover, "'") -- complement operator
					end start = true
				end
			end table.insert(symbolic_cover, separator_symbols[2])
			if i < ncomp or j < nterm then table.insert(symbolic_cover, separator_symbols[3]) end
		end
	end

	return table.concat(symbolic_cover)
end

return M
