-module(random_grid_tests).
%% ----------------------------------------------------
%% This module is used to do random testing.
%% The test generates random grids
%% and compares the results of the algorithms.
%%
%% Help on PropEr:
%% http://lj.rossia.org/users/eacher/100949.html
%% ----------------------------------------------------

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(RANDOM_TEST_GRID_FILE, "random_test_grid_buffer.txt").
-define(RANDOM_TEST_RESULT_FILE, "random_test_result_buffer.txt").
-define(RANDOM_TEST_LATENCIES_FILE, "random_test_latencies.csv").
-define(RUN_FIND_PATH_BASIC_CMD, "../../../RunFindPath randomTest").

algorithms_give_same_result_test_() ->
    {timeout, 600, [?_assert(
                       algorithms_give_same_result_test_no_timeout() == true)]}.

algorithms_give_same_result_test_no_timeout() ->
    NumberOfTests = 500,
    proper_arith:rand_start(now()),
    {ok, GridFD} = file:open(?RANDOM_TEST_GRID_FILE, [write, binary]),
    {ok, LatenciesFD} = file:open(?RANDOM_TEST_LATENCIES_FILE, [write, binary]),
    LatenciesHeaders =
        io_lib:format("jps_s_lat, jps_ns_lat, astar_s_lat, astar_ns_lat\n", []),
    file:write(LatenciesFD, LatenciesHeaders),
    ok = ?assert(proper:quickcheck(
                       prop_algorithms_give_same_result(GridFD, LatenciesFD),
                       {'numtests', NumberOfTests})),
    io:format(user,
              "\n--> The comparison of the algorithms with random "
              "tests is finished. ~p tests were run.\n\n", [NumberOfTests]),
    file:close(GridFD),
    file:close(LatenciesFD),
    true.

prop_algorithms_give_same_result(GridFD, LatenciesFD) ->
    MinMapWidth = 5,
    MinMapHeight = 5,
    MaxMapWidth = 20,
    MaxMapHeight = 20,
    MaxNonTraversablePercentage = 70,
    ?FORALL(
       {MapWidth, MapHeight, NonTraversablePercentage},
       grid_params_gen(MinMapWidth, MinMapHeight, MaxMapWidth, MaxMapHeight,
                       MaxNonTraversablePercentage),
       ?FORALL(
          {List},
          {proper_types:vector(
             MapWidth * MapHeight,
             traversable_percentage_gen(NonTraversablePercentage))},
          begin
              %% We place start and target on the first row and last row.
              Start = proper_arith:rand_int(0, MapWidth-1),
              Target =
                  MapWidth * (MapHeight -1)
                  + proper_arith:rand_int(0, MapWidth-1),
              IODataGrid = make_io_data_for_grid(List, Start, Target, 0),
              file:position(GridFD, bof),
              file:truncate(GridFD),
              file:write(GridFD, IODataGrid),
              case catch compare_algo_runs(MapWidth, MapHeight, LatenciesFD) of
                  {segmentation_fault, Cmd} ->
                      io:format(user, "Segmentation Fault\n", []),
                      io:format(user, "Command in .eunit folder: ~p\n", [Cmd]),
                      halt(1);
                  Bool -> Bool
              end
          end)).

grid_params_gen(MinMapWidth, MinMapHeight, MaxMapWidth, MaxMapHeight,
                MaxTraversablePercentage) ->
    MapWidth = choose(MinMapWidth, MaxMapWidth),
    MapHeight = choose(MinMapHeight, MaxMapHeight),
    TraversablePercentage = choose(0, MaxTraversablePercentage),
    {MapWidth, MapHeight, TraversablePercentage}.

traversable_percentage_gen(NonTraversablePercentage) ->
    TraversablePercentage = 100 - NonTraversablePercentage,
    proper_types:frequency([{TraversablePercentage, 1},
                            {NonTraversablePercentage, 0}]).

make_io_data_for_grid([], _Start, _Target, _GridIndex) ->
    <<>>;
make_io_data_for_grid([ Digit | GridListRest], Start, Target, GridIndex) ->
    FunStoreCharAndDoRecursion =
        fun(Char) ->
                [ Char | make_io_data_for_grid(GridListRest, Start, Target,
                                               GridIndex +1)]
        end,
    case GridIndex of
        Start -> FunStoreCharAndDoRecursion(<<$S>>);
        Target -> FunStoreCharAndDoRecursion(<<$T>>);
        _ ->
            case Digit of
                0 -> FunStoreCharAndDoRecursion(<<$0>>);
                1 -> FunStoreCharAndDoRecursion(<<$1>>)
            end
    end.

compare_algo_runs(MapWidth, MapHeight, LatenciesFD) ->
    {PathLength1, SLat1, NSLat1} =
        run_algo(MapWidth, MapHeight, jps),
    {PathLength2, SLat2, NSLat2} =
        run_algo(MapWidth, MapHeight, astar),
    LatenciesLine = io_lib:format("~p, ~p, ~p, ~p\n",
                                  [SLat1, NSLat1, SLat2, NSLat2]),
    file:write(LatenciesFD, LatenciesLine),
    io:format(user, "\n----------------> Grid Size: ~p x ~p, Path Length 1:"
              " ~p, Path Length 2: ~p\n",
              [MapWidth, MapHeight, PathLength1, PathLength2]),
    PathLength1 == PathLength2.

run_algo(MapWidth, MapHeight, Algo) ->
    Cmd = binary_to_list(iolist_to_binary(
                           io_lib:format("~s ~p ~p ~p",
                                         [?RUN_FIND_PATH_BASIC_CMD,
                                          Algo, MapWidth, MapHeight]))),
    Out = os:cmd(Cmd),
    catch_segmentation_fault(Out, Cmd),
    {ok, [{Algo,[{length,PathLength}, {secLatency,SLat},
                 {nsecLatency,NSLat}]}]} =
        file:consult(?RANDOM_TEST_RESULT_FILE),
    {PathLength, SLat, NSLat}.

catch_segmentation_fault(CmdOut, Cmd) ->
    case re:run(CmdOut, "Segmentation fault") of
        nomatch -> ok;
        {match, _} -> throw({segmentation_fault, Cmd})
    end.
