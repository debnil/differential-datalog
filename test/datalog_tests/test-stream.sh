#!/bin/bash

set -e

./run-test.sh stream release

run_test() {
    echo Running mem leak test for $1 iterations.
    ( for (( i=1; i<=$1; i++ ))
    do
        echo "start;
        insert Chunk(\"{\\\"field\\\": $i}\"),
        insert Chunk(\"{\\\"fild\\\": $i}\"),
        commit dump_changes;"
    done) |
        /usr/bin/time -o stream_mem -f "%M" ./stream_ddlog/target/release/stream_cli -w 4 --no-store > stream_mem.dump
}

run_memleak_test() {
    run_test 100
    mem_short=$(cat stream_mem)
    run_test 100000
    mem_long=$(cat stream_mem)
    echo "mem_short=$mem_short, mem_long=$mem_long"
    if [ "$mem_long" -gt $(( 2*"$mem_short" )) ]
    then
        echo "Possible memory leak: mem_short=$mem_short, mem_long=$mem_long"
        exit 1
    fi
}

run_stream_query_test() {
    echo Running streaming queries test for $1 batches of $2 queries and $3 workers;
    (
    # Populate the store.
    echo "start;"
    for (( i=1; i<=$2; i++ ))
    do
        echo "insert KVStore(${i}, \"${i}\"),"
    done
    echo "commit dump_changes;"

    # Run queries
    for (( i=1; i<=$1; i++ ))
    do
        echo "start;"
        for (( j=1; j<=$2; j++ ))
        do
            echo "insert KVStreamQuery(${j}),"
        done
        echo "commit dump_changes;"
    done) > stream_bench.dat
    /usr/bin/time ./stream_ddlog/target/release/stream_cli -w $3 --no-store < stream_bench.dat > stream_stream_queries.dump

}

run_rel_query_test() {
    echo Running relational queries test for $1 batches of $2 queries and $3 workers;
    (
    # Populate the store.
    echo "start;"
    for (( i=1; i<=$2; i++ ))
    do
        echo "insert KVStore(${i}, \"${i}\"),"
    done
    echo "commit dump_changes;"

    # Run queries
    for (( i=1; i<=$1; i++ ))
    do
        echo "start;"
        for (( j=1; j<=$2; j++ ))
        do
            echo "insert KVRelQuery(${j}),"
        done
        echo "commit dump_changes;"
        echo "start;"
        for (( j=1; j<=$2; j++ ))
        do
            echo "clear KVRelQuery;"
        done
        echo "commit dump_changes;"

    done) > stream_bench.dat
    /usr/bin/time ./stream_ddlog/target/release/stream_cli -w $3 --no-store < stream_bench.dat > stream_rel_queries.dump

}

run_stream_query_test 1000 1000 1
run_stream_query_test 1000 1000 2
run_stream_query_test 1000 1000 4
run_rel_query_test 1000 1000 1
run_rel_query_test 1000 1000 2
run_rel_query_test 1000 1000 4

run_memleak_test
