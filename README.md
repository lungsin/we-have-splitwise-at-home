# Splitwise at home: Splitbill CLI

This is a simple cli program, meant to be a quick resolver to simplify settlement when splitting bills. 
If you know about splitwise, this has similar utility. You put in a bunch of bills definition and the program will
figure out a simple way to settle.

## Why not Splitwise?

Splitwise requires all parties involved to have a spliwise account.
Not everyone wants to go through the hassle of setting it up, especially when it's a one-time settlement.

## Usage

### Compiling the program

I wrote two versions of the program: C++ and Jai. They have the same functionality, so to compile the program, you only
need either a C++-11 compiler, or a jai compiler.

```bash
# Compile C++ version
g++ splitbill.cc -o splitbill -std=c++11 -O2

# Compile jai version
jai splitbill.jai
```

### Using the program

Run the compiled program and input the bills. A bill follows the following format:
```
<name_1> <name_2> <name_3> ... <name_N> -> <payer_name> <paid_amount>
``` 
Here `<payer_name>` pays the bill for `<paid_amount>` dollar.
The bill is divided equally for the names on the left of `->`;
So, each name on the left owes `<payer_name>` about `<paid_amount> / N`.

Here is an example to illustrate the program usage:
```txt
# alice owes bob 100
alice -> bob 100

# bob and charlie owes alice 50 each (alice is not included in the split, so each person owes 100 / 2)
bob charlie -> alice 100

# alice, bob, and charlie owes daniel 25 each
# (daniel is included in the split calculation, so each person owes 100 / 4)
alice bob charlie daniel -> daniel 100

# Lines which do not adhere to the format are ignored (hence why this comment-like thing can be here)
# Also note that multilines bills are not supported, so the following two lines are IGNORED
#    alice bob -> 
#                     john 100

# Once you're done inputing, you can use the shortcut to indicate EOF: Ctrl+D for linux and Ctrl+Z for windows
```

The program will then outputs the settlement recommendation. 
For example the above input will produce the folowing outputs: 
```txt
  alice -> bob    : 25.00
charlie -> daniel : 75.00
```
meaning alice needs to pay bob $25 and charlie needs to pay daniel 75$.


## FAQ

### Why CLI and not TUI / GUI?

It's to keep the scope small! This project is meant to be my little recreational programming session.

### Why two languages (Jai and C++)?

I thought this problem had the perfect complexity as an exercise to learn jai. 
But then, at the time of writing this, jai is currently on closed-beta
and I want my friends (which don't have acces to jai) to be able to use this tools.
So, I implemented this first in C++ to prototype the algorithm and then reimplement it in jai.

### Is it fast?

Yes, it runs in O(N log N), where N is the number of people involved.

### Does it output the optimal solution?

Fun fact: finding an optimal solution here is actually NP-Hard. So, no!

But the current implementation is guaranteed to be at most 1.5 times the optimal solution. It's good enough!

### What's the algorithm used here?

Here's a rough description of the algorithm:

First, find out the net balance of each person after considering all the bills. There will be 
people with debts and people with receivables. We'll then make a settlement plan by having a transaction 
between people with debts to people with receivables.

If there are two people with the same amount of debt and receivable, we
pair them up since their settlement can be done in just one transaction. Otherwise, we greedily pair up the person with
highest debt with the person with highest receivable, and try to settle as much money as possible between the two (
the person with debt will transfer min(debt, receivable) amount of money). We repeat this process until everyone is
settled.

Note for the optimality: you can check out the following paper which show that it has 1.5 approximability.

https://www.cs.cmu.edu/afs/cs/user/dwoodruf/www/w06mcip.pdf

### Why is the jai version twice as long at the C++ program?

It's because jai doesn't have an equivalent of `std::map`, so I have to implement a BBST (in this case an AVL tree).

### Does anyone actually ask these questions?

No, lol. I wrote this whole FAQ section before publishing the repo.

Initially, I wanted to name this section as "Fun Fact" instead of "FAQ", but it's funnier this way!


