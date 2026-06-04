# zig-astar-example 🐭🧀

A tiny, silly demo of the [zig-astar](https://github.com/keenanjohnson/zig-astar)
pathfinding library: a mouse scampers through a freshly-generated maze to reach
the cheese, animated right in your terminal.

```sh
zig build run
```

Each round generates a random "perfect" maze, asks `zig-astar` for the shortest
path from the 🏠 to the 🧀, then walks the 🐭 along it one step at a time,
leaving a crumb trail. Press `Ctrl+C` to stop.

Built and tested against Zig 0.16.0.

## What this example is for

It exists to show how to **pull the library into your own project** and use its
API — not just read it. The interesting bits:

- **Depending on it** — [build.zig.zon](build.zig.zon) has the dependency entry,
  added with:

  ```sh
  zig fetch --save git+https://github.com/keenanjohnson/zig-astar#v0.0.1
  ```

  and [build.zig](build.zig) wires it in as the `astar` import.

- **Using it** — [src/main.zig](src/main.zig) describes the graph by giving
  `zig-astar` a context struct with `heuristic()` and `neighbors()`, then calls
  `Search.findPath(allocator, maze, start, goal)`. The returned slice of cells is
  the path (and is ours to free).

## License

[Apache-2.0](LICENSE)
