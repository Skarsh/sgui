# TODOs

## Active
* OpenGL rendering, be able to render basic rect commands to begin with.
* Rethink how to structure text creation, meaning `text` helper proc vs `element_equip_text`.
    specifically there's been a bug with text color being zeroed out so text was not visible.
    Would text just having a sensible default styling be enough?

## Bugs

## Backlog
* Prune "dead" ui elements (they're still cached in the map)
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

