(
  <- what,
  then
)

what if every function call is potentially awaitable?
[
  <-(~(a, f) => f(a))(),
]

[
  <-((a, f) ~> f(a))(),
]
[
  <-((a, f) ≈> f(a))(),
]
[
  <-((a, f) ~=> f(a))(),
]

<- all([
  f(a),
  f(b),
])

asdf <= f(a)


(a, f) ~> 

std = load("std")
pogbear = load("pogbear")
ports = load("config").ports

res = await all(map(ports, pogbear.start), (<-))
std.log("finished running", res)
each(["finished running", res], std.log)

add3 = x => x + 3
add3 = (+ 3)

add = (x, y) => x + y
add = (+)


map([1, 2, 3], n => n + 3)
map([1, 2, 3], (3 +))

res = map(map([1, 2, 3], (+)), 3)
log(res) // [4,5,6]


any(res, r => r.type :: {
  Error -> std.fatal(err)
})

cat := (list, joiner) => max := len(list) :: {
  0 -> ''
  _ -> (sub := (i, acc) => i :: {
    max -> acc
    _ -> sub(i + 1, acc.len(acc) := joiner + list.(i))
  })(1, clone(list.0))
}

len(list) :: { 0->0, _->'what' }



log.Fatalf(http.Serve())

<-bear :: {
  err(msg) -> log.fatal("something bad?", msg)
  ok(_) -> log.info("stopped all good", bear.id)
}

enum Status { err(1), ok(1) }

<-bear :: {
  [ok, data] -> log.fatal("something bad?", msg)
  [err, wot] -> log.info("stopped all good", bear.id)
}

<-bear :: {
  .err(msg) -> log.fatal("something bad?", msg)
  .ok(_) -> log.info("stopped all good", bear.id)
}

is = type :: {
  .[type](_) -> true,
  _ -> false,
}

is = typ => b => type(typ) == type(b)

any(res, ::.err)
any(res, (::).ok)

is2 = :: {
  2 -> true
  _ -> false
}


clone := x => type(x) :: {
  'string' -> '' + x
  'composite' -> reduce(keys(x), (acc, k) => acc.(k) := x.(k), {})
  _ -> x
}



std = load("std")

server = std.listen_tcp("0.0.0.0:" + string(port))

serve = () => (
  async server.start(string(port))
)

serve = () => (
  chan = makechan()
  (async () => (
    await std.time.sleep(10),
    chan<-10
  ))()
  waiter = async () => await chan.accept() :: {
    10 -> ()
    _ -> await waiter()
  }
  await waiter()
)
await serve()


serve = () => await server.serve()


expression sketch, use s-expressions?
((1+2) (3+4))
(
  (1+2)
  (+4)
)



requestLoop = async () => (
  req = await server.accept()
  req.type :: {
    Error -> ()
    data -> (
      resp = await fetch(server, 'hello')
      respond(server, req, resp)
      requestLoop()
    )
  }
)

proxyLoop = async () => (
  await server.accept() :: {
    {type:Error, ...} -> ()
    {type:Data, data} -> (
      resp = await fetch(server, 'hello')
      respond(server, req, resp)
      proxyLoop()
    )
  }
)


for (true) {
  req = await server.accept()
  req
}

(

)

-module(tut15).

-export([start/0, ping/2, pong/0]).

ping(0, Pong_PID) ->
    Pong_PID ! finished,
    io:format("ping finished~n", []);

ping(N, Pong_PID) ->
    Pong_PID ! {ping, self()},
    receive
        pong ->
            io:format("Ping received pong~n", [])
    end,
    ping(N - 1, Pong_PID).

pong() ->
    receive
        finished ->
            io:format("Pong finished~n", []);
        {ping, Ping_PID} ->
            io:format("Pong received ping~n", []),
            Ping_PID ! pong,
            pong()
    end.

start() ->
    Pong_PID = spawn(tut15, pong, []),
    spawn(tut15, ping, [3, Pong_PID]).


ping = (n, chan) => <-chan {
  0 -> chan<-2
  n -> 
}




std = load("std")

std.new_tcp_listener()
listener.listen

start := () => (
  end := server.start(PORT)
  log(f('merlot start', [Port]))
)

start()

new := () => (
  router = newRouter()
  start = port => std.listen_tcp("0.0.0.0:" + string(port), evt => (
    route.catch(router, params)
  ))
  addRoute = (url, handler) => route.add(router, url, handler)
  { addRoute, start }
)



each := (list, f) => (
  max := len(list)
  (sub := i => i :: {
    max -> ()
    _ -> (
      f(list.(i), i)
      sub(i + 1)
    )
  })(0)
)


std := load("std")

listener = std.listen_tcp("0.0.0.0:" + string(port))
listener.accept((req) => (
  req.code :: {
    {error: null, data} -> data
    {error, _} -> log.error("error on recv", error)
  }
))

fn asdf(asdf, asdf) {
  ksdfkj

}

fn(asdf, asdf) { asdf, asdf, asdf }

(fn(asdf) { asdf })()

(fn(p) { print(p) })()

asdf ::= asdf {
  _
}

fn(asdf, asdf) (1, 2, 3)

new := () => (
  router := route.new()

  ` routes added to router here `

  start := port => listen('0.0.0.0:' + string(port), evt => (
    (route.catch)(router, params => (req, end) => end({
      status: 404
      body: 'service not found'
    }))

    evt.type :: {
      'error' -> log('server start error: ' + evt.message)
      'req' -> (
        log(f('{{ method }}: {{ url }}', evt.data))

        handleWithHeaders := evt => (
          handler := (route.match)(router, evt.data.url)
          handler(evt.data, resp => (
            resp.headers := hdr(resp.headers :: {
              () -> {}
              _ -> resp.headers
            })
            (evt.end)(resp)
          ))
        )
        [allow?(evt.data), evt.data.method] :: {
          [true, 'GET'] -> handleWithHeaders(evt)
          [true, 'POST'] -> handleWithHeaders(evt)
          [true, 'PUT'] -> handleWithHeaders(evt)
          [true, 'DELETE'] -> handleWithHeaders(evt)
          _ -> (evt.end)({
            status: 405
            headers: hdr({})
            body: 'method not allowed'
          })
        }
      )
    }
  ))

  {
    addRoute: (url, handler) => (route.add)(router, url, handler)
    start: start
  }
)


()
=> (

)

matchPath = (pattern, path) => {
  params = {}
  [path, params, ...rest] = split(path, '?')
  params :: {
    () -> (),
    '' -> (),
    _ -> (
      queries = map(split(params, '&'), pair => split(pair, '='))
      each(queries, pair => params[pair.0] = decode(pair.1))
    ),
  }

  {
    params: 
  }
  params >{
    () -> 
  }

  [len(desired) < len(actual) | len(desired) == len(actual), pattern] :: {
    ` '' is used as a catch-all pattern `
    [_, ''] -> params
    [true, _] -> findMatchingParams(0)
    _ -> ()
  }
}

_ matchPath := (pattern, path) => (
  params := {}

  ` process query parameters `
  pathParts := split(path, '?')
  path := pathParts.0
  pathParts.1 :: {
    () -> ()
    '' -> ()
    _ -> (
      queries := map(split(pathParts.1, '&'), pair => split(pair, '='))
      each(queries, pair => params.(pair.0) := pctDecode(pair.1))
    )
  }

  desired := splitPath(pattern)
  actual := splitPath(path)

  max := len(desired)
  findMatchingParams := (sub := i => i :: {
    max -> params
    _ -> (
      desiredPart := (desired.(i) :: {
        () -> ''
        _ -> desired.(i)
      })
      actualPart := (actual.(i) :: {
        () -> ''
        _ -> actual.(i)
      })

      desiredPart.0 :: {
        ':' -> (
          params.(slice(desiredPart, 1, len(desiredPart))) := actualPart
          sub(i + 1)
        )
        '*' -> (
          params.(slice(desiredPart, 1, len(desiredPart))) := cat(slice(actual, i, len(actual)), '/')
          params
        )
        _ -> desiredPart :: {
          actualPart -> sub(i + 1)
          _ -> ()
        }
      }
    )
  })

  [len(desired) < len(actual) | len(desired) = len(actual), pattern] :: {
    ` '' is used as a catch-all pattern `
    [_, ''] -> params
    [true, _] -> findMatchingParams(0)
    _ -> ()
  }
)