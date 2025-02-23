# Zempl

I honestly only made this template language because I was have trouble doing the samething using C and wanted to learn zig. Inspired by the the Golang html/template standard libary package, I have create simpler but effective html template language.

## Ussage 

The source code is all in a single file so copy the file into you project

```bin
cp template.zig /your/target/directory/template.zig
```

Import the file as needed in your project and add it to your build, it is only reliant on zig v0.13.0

```bin
zig build-exe -femit=./main -ofmt=elf src/main.zig /your/target/directory/template.zig
```

## Examples

This project has a http web server that allows you to make a request to localhost:8080/ to get the homepage of the site

### Build

Run the build script to build the binary

```bin
./build.sh
```

### Running

```bin
./bin/main
```

curl or Vist [localhost](http://localhost:8080/) in the browser to see the rendered template

## Template Syntax

- two open brackets "{{", at least one space ' '..., template name "A..Za..z", at least one space ' '..., two closing brackets "}}"
```html
<!doctype html>
<html>
  <head>
    <title>{{ title }}</title>
  </head>
  <body>
    <h1>{{ header }}</h1>
  </body>
</html>
```

These slots will simpily get string match and replace with you data if provided

- slotted template: <h1>{{ header }}</h1> and .{ .header = "Good Morning America" }; becomes <h1>Good Morning America</h1>
- number: <li>{{ 10 }}</li> becomes <li>10</li>
- float: <div>{{ 1.883 }}</div> becomes <div>1.883</div>
- float: <div>{{ 1.883 }}</div> becomes <div>1.883</div>

```zig
// zig file main.zig
const std = @import("std"); 
const std = @import("/path/to/your/template.zig"); 

const HomePage = struct {
    .title = "My home page",
        .content = "<h1>Some amazing essay about htmx</h1><p>How to build website dead simple</p>", 
        // simple zig slices 
};

pub fn main() void {
    var arena: std.heap.ArenaAllocator = undefined;
    var ok: bool = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer {
        ok = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);
        if (!ok) {
            std.log.err("falied to reset the arena\n", .{});
        }
        arena.deinit();
    }

    ally = arena.allocator();

    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ header }}</h1>
        \\<p>The weather is {{ 10.8 }} degrees today</h1>
        \\</body>
        \\</html>
        ;

    const template_content = template_execute(ally, @constCast(template), .{ 
        .title = "this is the home page of the website", 
        .header = "the main header", 
    }) orelse "";

    std.debug.print("template_content=\n{s}\n", .{template_content}); 

    return;
}
```
