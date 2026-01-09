# Frequently Asked Question

## Why CLI and not TUI / GUI?

It's to keep the scope small! This project is meant to be my little recreational programming session.

## Why two languages (Jai and C++)?

I thought this problem had the perfect complexity as an exercise to learn jai. 
But then, at the time of writing this, jai is currently on closed-beta
and I want my friends (which don't have acces to jai) to be able to use this tools.

## Is it fast?

Yes, it runs in O(N log N), where N is the number of people involved.

## Does it output the optimal solution?

Fun fact: finding an optimal solution here is actually **NP-Hard**. So, no!

But the current implementation is guaranteed to be at most **1.5** times the optimal solution. It's pretty good!

I must say that there are other polynomial algorithm in the literature with better approximation bound. 
However, the runtime is quite impractical; there's a 1.25-approximation algorithm that runs in O(N^9), and a 1.2-approximation
algorithm that runs in O(N^186).

## What's the algorithm used here?

Here's a rough description of the algorithm:

- Find out the net balance of each person after considering all the bills. There will be 
people with **debts** and people with **receivables**. We'll then make a settlement plan by having a transaction 
between people with debts to people with receivables.

- Then we repeat this process until everyone are settled:

    - If there are two people with the same amount of debt and receivable, we
    pair them up since their settlement can be done in just one transaction.

    - Otherwise, we greedily pair up the person with highest debt with the person with highest receivable, and 
    settle as much money as possible between the two (the person with debt will transfer min(debt, receivable) amount of money).

Note for the optimality: you can check out the following paper which show that it has 1.5 approximability.

https://www.cs.cmu.edu/afs/cs/user/dwoodruf/www/w06mcip.pdf

## Does anyone actually ask these questions?

No, lol. I wrote this whole FAQ section just to add this joke.

