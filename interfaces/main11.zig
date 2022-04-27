
            const Result = union {
                expr: *Expr,
                err: ErrInfo,
            };
            const operator = self.previous() {
                .expr => |expr| expr,
                .err => |err| return Result.err(err),
            };
            const right = switch (self.unary()) {
                .expr => |expr| expr,
                .err => |err| return Result.err(err),
            };