# TODOs

## Active

## Bugs
* Text on `build_complex_ui` is missing

## Backlog
* Prune "dead" ui elements (they're still cached in the map)
* Make our own Renderer, start with OpenGL
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

