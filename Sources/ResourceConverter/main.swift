//
//  main.swift
//  Resource Converter
//
//  Created by Zoe Van Brunt on 1/2/22.
//

import Foundation
import ConsoleKit

let console: Console = Terminal()
var input = CommandInput(arguments: CommandLine.arguments)
var context = CommandContext(console: console, input: input)

var commands = Commands(enableAutocomplete: true)
commands.use(XMLStringsResConvert(), as: XMLStringsResConvert.name, isDefault: false)

do {
    let group = commands.group(help: "Converting Android resources to iOS resources.")
    try console.run(group, input: input)
} catch {
    console.error("\(error)")
    exit(1)
}
