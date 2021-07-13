extern fn print(i32) void;

export fn add(a: i32, b: i32) void {
    print(a + b);
}

export fn newGame() {

}

const Game = struct {
    width: u32,
    height: u32,
}