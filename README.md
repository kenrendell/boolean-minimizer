# Boolean Minimizer

Minimize Boolean functions using [Quine-McCluskey](https://en.wikipedia.org/wiki/Quine%E2%80%93McCluskey_algorithm) and [Petrick's](https://en.wikipedia.org/wiki/Petrick%27s_method) algorithm.

## Usage

``` sh
# Print help message
boolean-minimizer

# Minimize Boolean function F(A, B, C) with minterms m(0, 1, 2, 5, 6, 7) in sum-of-products (SOP) form.
boolean-minimizer --input 3 --minterm 0 1 2 5 6 7

# Minimize Boolean function F(A, B, C) with minterms m(0, 1, 2, 5, 6, 7) in product-of-sums (POS) form.
boolean-minimizer --product-of-sum --input 3 --minterm 0 1 2 5 6 7

# Minimize Boolean function F(A, B, C) with maxterms M(3, 4) in product-of-sums (POS) form.
boolean-minimizer --input 3 --maxterm 3 4

# Minimize Boolean function F(A, B, C) with maxterms M(3, 4) in sum-of-products (SOP) form.
boolean-minimizer --sum-of-product --input 3 --maxterm 3 4

# Using custom inputs, minimize Boolean function F(X, Y, Z)
boolean-minimizer --input x y z --minterm 0 1 2 5 6 7

# Minimize Boolean function F(A, B, C, D) with don't-care terms.
boolean-minimizer --input 4 --minterm 0 2 5 6 7 8 9 13 --optional-term 1 12 15

# Minimize Boolean function F(A, B, C, D) with don't-care terms and print all solutions.
boolean-minimizer --all --input 4 --minterm 0 2 5 6 7 8 9 13 --optional-term 1 12 15

# To show minimization process.
boolean-minimizer --verbose --input 4 --minterm 0 2 5 6 7 8 9 13 --optional-term 1 12 15
```
