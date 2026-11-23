# Working here

Do not add to the README, that is for humans and there is an expectation all the writing there is by humans for humans.

Code should be self documenting, and if you need a comment to explain logic it is probably an indication that the code is too complicated. However, there are always weird edge cases, in those cases a nice comment explaining why really helps. The ideal state is that someone with no context could read a file and understand each line, they should not need to read through docs or open a spec file to understand why an if block exists.

## Tests

Be really careful writing tests. If you add any, there should be a follow up attempt to do mutation testing. If we have fragile tests that are testing implimination details rather than actual behavior that is bad!

## Ending

Have fun man, this is a personal project!
