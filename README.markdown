# Playdown
**Playdown** — *noun*: A place where people convert Swift Playgrounds to Markdown

```swift
println("This README was converted from README.swift!")

```

# Usage
Playdown was made to be run from the Terminal.

Install with npm, and run Playdown on any Swift file

```
$ npm install -g playdown
$ playdown Contents.swift
```

Alternatively, you can download `Playdown.swift`, put it in the right directory, and run it with `swift Playdown.swift Contents.swift`.


```swift
func use() {
    npm.install("playdown", options: "-g")
    Terminal.run("playdown Contents.swift") // Works for any .swift file!
}

```

# Features

* Convert a playground to a Markdown document, perfect for blog posts
* Support for lots of Markdown features, like headings, lists, block quotes, styles, and links.
* Supports Github Flavored Markdown


```swift
func cool() -> Bool {
    return Playdown.headings()
            .lists()
            .blockQuote()
            .codeBlocks()
            .inlineStyles()
            .links() == true
}

```

# Tests
If Playdown doesn't work well for one of your playgrounds, please open a pull request with your playground and the expected output.

To run the tests, you can use the `test` script in the root folder of this project.


```swift
func test() -> (Test, String) {
    return (./test, "We would love if you contributed more tests!")
}
```

