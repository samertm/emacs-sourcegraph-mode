# emacs-sourcegraph-mode [![Build Status](https://travis-ci.org/sourcegraph/emacs-sourcegraph-mode.png?branch=master)](https://travis-ci.org/sourcegraph/emacs-sourcegraph-mode)

**WORK IN PROGRESS**

Emacs mode for Sourcegraph, powered by srclib, for automatically configured, high-quality programming language support in Emacs. Currently provides:

* documentation lookups
* type information
* find usages (across all open-source projects globally)

for any language srclib supports, currently:

* Go
* JavaScript (Node.js)


Check out the screenshots below, and the
[screencast on YouTube](https://www.youtube.com/watch?v=cm59qQD6khs).

![screenshot](https://s3-us-west-2.amazonaws.com/sourcegraph-assets/emacs-sourcegraph-mode-screenshot-0.png)

![screenshot](https://s3-us-west-2.amazonaws.com/sourcegraph-assets/emacs-sourcegraph-mode-screenshot-1.png)

## Installation

Put this in your `.emacs.d`, and then add a hook or just run `sourcegraph-mode`
manually to enable it in a buffer.

Be sure you've installed the
[srclib](https://sourcegraph.com/sourcegraph/srclib) toolchains for the
programming language you're using.

Then, in any file (with `sourcegraph-mode` enabled), run `sourcegraph-describe`
(or C-M-.) to see docs, type info, and examples.

Docs and type info are retrieved locally if possible; otherwise they are fetched
from [Sourcegraph.com](https://sourcegraph.com). Examples are always fetched
from [Sourcegraph.com](https://sourcegraph.com).

## Security

Your local code is never uploaded to Sourcegraph, but the "definition paths" of
things you look up are sent (to retrieve examples from the Sourcegraph API). The
definition paths include the following information about the definition under
your cursor (but do not include any source code):

* repository URI (e.g., "github.com/user/repo")
* package name (e.g., "foo" for an npm package named "foo")
* scope path (e.g., `MyClass.prototype.foo` for a JavaScript `foo` method on `MyClass`)
