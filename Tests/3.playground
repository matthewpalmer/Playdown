//: Playdown - *noun*: A place where people convert Swift Playgrounds to Markdown
//: > This README was converted from the playground at `tests/3.playground`!

println("Playdown converts your Swift playgrounds to Markdown")

/*:
# Usage
Playdown was made to be run from the Terminal.

1. Download Playdown.swift
2. Run it with `swift Playdown.swift YourPlayground/Contents.swift`
*/

func use() {
    Playdown.download()
    Playdown.run("YourPlayground/Contents.swift") // Works for any .swift file!
}

/*:
# Features

* Convert Playground Markup Language to a Markdown document, perfect for blog posts
* Support for lots of Markdown features, like headings, lists, block quotes, code blocks, inline styles, and links.
* Supports Github Flavored Markdown, though I'm happy to accept PRs for improvements.
*/

func cool() -> Bool {
    return Playdown.headings()
            .lists()
            .blockQuote()
            .codeBlocks()
            .inlineStyles()
            .links() == true
}

/*:
# Tests
We need more tests!

If Playdown doesn't work well for one of your playgrounds, please open a pull request with your playground and the expected output.

To run the tests, you can use the `test` script in the root folder of this project.
*/

func test() -> String {
    return "We would love if you contributed more tests!"
}
