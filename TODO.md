# TODOs

## Active
* Text needs to become "just" a capability of an element, not it's own specific type of element as it kind of is now.
    This means that the Text capability needs to compose well together with the other ones.
    How this would work currently is that a text element will be on top, causing problems for interactivity
    checks as hover etc. This could be circumvented by skipping text elements for interactivity, but that
    makes it hard then to have embossed animation on the text on hover etc. I think this just shows that even if its
    simple layout wise to have text as its own special kind of element, its gonna make things much harder and more
    complex further down. Due to this I will spend some significant time now trying to figure out a way to "unify"
    the text capability with the others.
    Issues found so far:
        - Adding padding to an element and then equip string on its causes sizing issues
        - Text needs its own type of aligment and padding, since it shouldn't be its own kind of element anymore.

* Remove duplicate fields of `Element_Content` in `UI_Element` and `Element_Config`, it has already caused bugs.
* Next goal: A single button ui procedure that can make button with texture, text, clickable, hoverable / hot 
    and active.

## Bugs
* Currently we will make a newline even if there's a space crossing the "line border".
    This means that if we split on the space after three in this string, "one two three \nfour five",
    we'll end up with a completely empty line between "three" and "four" here.

## Backlog
* Prune "dead" ui elements
* Take window size into consideration, elements should adapt accordingly
* Styling - Style stacks? At least it needs to be a bit simpler.
* Make our own Renderer, start with OpenGL
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

