//! A fun, silly demo of the zig-astar library: a 🐭 mouse scampers through a
//! freshly-generated maze to reach the 🧀 cheese, animated in your terminal.
//!
//!   zig build run
//!
//! Each round generates a random maze, asks zig-astar for the shortest path,
//! then walks the mouse along it one step at a time. Press Ctrl+C to stop.

const std = @import("std");
const astar = @import("astar");

const ROWS = 21; // must be odd so the maze carves cleanly
const COLS = 41; // must be odd

const Point = struct { x: i32, y: i32 };

/// The graph we hand to zig-astar: a 2D grid where '#' cells are walls.
/// It only holds a pointer to the grid, so it's cheap to pass by value.
const Maze = struct {
    grid: *const [ROWS][COLS]u8,

    fn walkable(self: Maze, p: Point) bool {
        if (p.x < 0 or p.y < 0 or p.x >= COLS or p.y >= ROWS) return false;
        return self.grid[@intCast(p.y)][@intCast(p.x)] != '#';
    }

    /// Manhattan distance — admissible for 4-directional, uniform-cost movement.
    pub fn heuristic(_: Maze, node: Point, goal: Point) u32 {
        return @abs(node.x - goal.x) + @abs(node.y - goal.y);
    }

    /// Report the walkable 4-neighbors of `node`, each costing 1 step.
    pub fn neighbors(self: Maze, node: Point, out: Search.Successors) !void {
        const deltas = [_]Point{
            .{ .x = 1, .y = 0 },  .{ .x = -1, .y = 0 },
            .{ .x = 0, .y = 1 },  .{ .x = 0, .y = -1 },
        };
        for (deltas) |d| {
            const next = Point{ .x = node.x + d.x, .y = node.y + d.y };
            if (self.walkable(next)) try out.add(next, 1);
        }
    }
};

const Search = astar.AStar(Point, u32, Maze);

/// Carve a "perfect" maze (exactly one path between any two cells) with an
/// iterative recursive-backtracker. Cells live at odd coordinates; walls
/// between them get knocked out as we visit.
fn generateMaze(grid: *[ROWS][COLS]u8, rand: std.Random) void {
    for (grid) |*row| @memset(row, '#');

    var stack: [ROWS * COLS]Point = undefined;
    var sp: usize = 0;
    grid[1][1] = ' ';
    stack[sp] = .{ .x = 1, .y = 1 };
    sp += 1;

    while (sp > 0) {
        const cur = stack[sp - 1];
        var dirs = [_]Point{
            .{ .x = 2, .y = 0 },  .{ .x = -2, .y = 0 },
            .{ .x = 0, .y = 2 },  .{ .x = 0, .y = -2 },
        };
        rand.shuffle(Point, &dirs);

        var carved = false;
        for (dirs) |d| {
            const nx = cur.x + d.x;
            const ny = cur.y + d.y;
            if (nx <= 0 or ny <= 0 or nx >= COLS - 1 or ny >= ROWS - 1) continue;
            if (grid[@intCast(ny)][@intCast(nx)] != '#') continue; // already visited

            // Knock out the wall between cur and the neighbor, then move in.
            grid[@intCast(cur.y + @divTrunc(d.y, 2))][@intCast(cur.x + @divTrunc(d.x, 2))] = ' ';
            grid[@intCast(ny)][@intCast(nx)] = ' ';
            stack[sp] = .{ .x = nx, .y = ny };
            sp += 1;
            carved = true;
            break;
        }
        if (!carved) sp -= 1; // dead end — backtrack
    }
}

/// Draw one frame. Every cell is exactly two terminal columns wide so the
/// double-width emoji stay aligned with the wall blocks.
fn render(
    grid: *const [ROWS][COLS]u8,
    trail: *const [ROWS][COLS]bool,
    mouse: Point,
    start: Point,
    goal: Point,
    steps_left: usize,
) void {
    std.debug.print("\x1b[H", .{}); // move cursor home; overwrite the old frame in place
    std.debug.print("  🐭  A* Maze Runner — {d} steps to the cheese (Ctrl+C to quit)   \n\n", .{steps_left});

    for (0..ROWS) |r| {
        for (0..COLS) |c| {
            const here = (mouse.x == @as(i32, @intCast(c)) and mouse.y == @as(i32, @intCast(r)));
            if (here) {
                std.debug.print("🐭", .{});
            } else if (goal.x == @as(i32, @intCast(c)) and goal.y == @as(i32, @intCast(r))) {
                std.debug.print("🧀", .{});
            } else if (start.x == @as(i32, @intCast(c)) and start.y == @as(i32, @intCast(r))) {
                std.debug.print("🏠", .{});
            } else if (grid[r][c] == '#') {
                std.debug.print("\x1b[32m██\x1b[0m", .{}); // green hedge
            } else if (trail[r][c]) {
                std.debug.print("\x1b[33m··\x1b[0m", .{}); // crumbs the mouse left
            } else {
                std.debug.print("  ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Zig 0.16's I/O lives behind the `std.Io` interface; this is what gives
    // us `sleep` for animation pacing.
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var grid: [ROWS][COLS]u8 = undefined;
    // Seed from a stack address — ASLR makes it differ between launches, which
    // is plenty of randomness for a toy maze.
    var prng = std.Random.DefaultPrng.init(@intCast(@intFromPtr(&grid)));
    const rand = prng.random();

    const start = Point{ .x = 1, .y = 1 };
    const goal = Point{ .x = COLS - 2, .y = ROWS - 2 };

    std.debug.print("\x1b[2J", .{}); // clear screen once up front

    while (true) {
        generateMaze(&grid, rand);
        const maze = Maze{ .grid = &grid };

        // The star of the show: ask zig-astar for the shortest path. The
        // returned slice is ours to free.
        const path = try Search.findPath(allocator, maze, start, goal) orelse continue;
        defer allocator.free(path);

        var trail = std.mem.zeroes([ROWS][COLS]bool);
        for (path, 0..) |step, i| {
            trail[@intCast(step.y)][@intCast(step.x)] = true;
            render(&grid, &trail, step, start, goal, path.len - 1 - i);
            try io.sleep(.fromMilliseconds(70), .awake);
        }

        try io.sleep(.fromMilliseconds(900), .awake); // savor the cheese, then start over
    }
}
