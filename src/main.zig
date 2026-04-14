const std = @import("std");
const sort = @import("sort.zig");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == std.heap.Check.leak) {
            std.debug.print("Aaaaa leak\n", .{});
        }
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        try stdout.print("Please provide an argument.\n", .{});
        try stdout.flush();
        return;
    }
    const n = try std.fmt.parseInt(u32, args[1], 10);
    const BufElementType: type = u32;
    const random_buf = try allocator.alloc(BufElementType, n);
    defer allocator.free(random_buf);

    var results = try sort.create_sort_container(allocator);
    defer allocator.free(results.buf);

    const data_range_min: BufElementType = 0;
    const data_range_max: BufElementType = 1000000000;

    try stdout.print("Testing arrays of size {} with a data range of {}.\n\n", .{n, data_range_max});

    try results.add(try sort.test_sorter("Radix Sort", allocator, sort.radix_sort, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Merge Sort Loop", allocator, sort.merge_sort_loop, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Merge Sort Recursive", allocator, sort.merge_sort_recursive, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Merge Sort Stack", allocator, sort.merge_sort_stack, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Quick Sort Recursive", allocator, sort.quick_sort_recursive, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Quick Sort Stack", allocator, sort.quick_sort_stack, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    try results.add(try sort.test_sorter("Quick Sort Threeway Recursive", allocator, sort.quick_sort_recursive_threeway, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    if (data_range_max < 50000000) try results.add(try sort.test_sorter("Counting Sort", allocator, sort.counting_sort, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

    if (n <= 64000) {
        try results.add(try sort.test_sorter("Insertion Sort", allocator, sort.insertion_sort, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

        try results.add(try sort.test_sorter("Selection Sort", allocator, sort.selection_sort, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);

        try results.add(try sort.test_sorter("Bubble Sort", allocator, sort.bubble_sort, stdout, random_buf, sort.randomize, data_range_min, data_range_max), allocator);
    }

    try results.truncate(allocator);

    try sort.merge_sort_loop(allocator, results.buf[0..]);
    try stdout.print("In order of speed: ", .{});
    for (0..results.buf.len - 1) |i| {
        try stdout.print("{s} ({:.0}/s), ", .{ results.buf[i].name, results.buf[i].efficiency });
    }
    try stdout.print("then {s} ({:.0}/s).", .{ results.buf[results.buf.len - 1].name, results.buf[results.buf.len - 1].efficiency });
    try stdout.print("\n", .{});
    try stdout.flush();
}
