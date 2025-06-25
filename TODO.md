# TODOs

## Active
* Bug squashing text

## Bugs
* In the `build_complex_ui` procedure, if the text is large enough it will completely overflow
    both to the left and right.
* Text element width doesn't care if there's a newline. The width of the element should only be as large
    as the widest line in the text.
* Currently we will make a newline even if there's a space crossing the "line border".
    This means that if we split on the space after three in this string, "one two three \nfour five",
    we'll end up with a completely empty line between "three" and "four" here.

## Backlog
* Clip text that goes out of the element bounds

* Unify Grow and Shrink procedure into a single one.

* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

