# TODOs

## Active
* Text alignment

## Bugs
* Currently we will make a newline even if there's a space crossing the "line border".
    This means that if we split on the space after three in this string, "one two three \nfour five",
    we'll end up with a completely empty line between "three" and "four" here.
* Text element width doesn't care if there's a newline. The width of the element should only be as large
    as the widest line in the text.

## Backlog

* Look into simplifying how to declare UI elements. E.g. not having to match open and close manually.
    Also define layout and styling in a simpler way?

* Review integer types throughout the project. Especially font and text calculation related ones.

* Figure out how to deal with Text Element vs "normal" Element. Currently we have kind field to keep track
    of which kind of Element it is.

* Unify Grow and Shrink procedure into a single one.

* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

* Text alignment

