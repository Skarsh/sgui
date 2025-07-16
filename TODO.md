# TODOs

## Active
* Basic UI interactivity - click, hover, active etc

## Bugs
* Currently we will make a newline even if there's a space crossing the "line border".
    This means that if we split on the space after three in this string, "one two three \nfour five",
    we'll end up with a completely empty line between "three" and "four" here.

## Backlog
* Take window size into consideration, elements should adapt accordingly
* Styling - Style stacks? At least it needs to be a bit simpler.
* Make our own Renderer, start with OpenGL
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

