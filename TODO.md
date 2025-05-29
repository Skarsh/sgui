# TODOs

## Board
* Investigate failing tests and fix the bugs
* Figure out how to deal with Text Element vs "normal" Element. Currently we have kind field to keep track
    of which kind of Element it is.

## Backlog
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.
