# Text Package

This documents aims to be a spec for how we want to design our text package.
The goals for this package is to provide the following features:
* Text editing
    * This should provide the potential for different underlying data structures, e.g. 
    gap buffer, rope etc.
* Text layout
* Text caching

All of this should be looked at holistically, meaning we should aim to use the same layout and
caching system for text that is editable and not.

## Text Edit
The entrypoint for text editing in the text package is through `text_edit.odin`.
It wraps text editing functionality by using the api exposed by `text_buffer.odin`.
The `Text_Buffer` should abstract underlying storage data structues, such as gap buffer or 
rope. This is done so that the usage of the text buffer api doesn't change, but the user will
have the possibility to select the underlying storage data structure that fits their problem
domain the best.

## Text Layout
TODO


## Text Caching
TODO
