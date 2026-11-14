// SPDX-License-Identifier: MIT
#include "allocation-diag-policy.h"
#include <cassert>
#include <thread>
#include <vector>
#include <cstdio>

int main() {
    using namespace bc250_allocdiag;
    constexpr auto oom = static_cast<std::int32_t>(0x8007000eu);
    constexpr auto fail = static_cast<std::int32_t>(0x80004005u);
    constexpr auto removed = static_cast<std::int32_t>(0x88760870u);
    static_assert(descriptor_failure(oom, false) == oom);
    static_assert(descriptor_failure(fail, false) == fail);
    static_assert(descriptor_failure(oom, true) == removed);
    static_assert(descriptor_failure(fail, true) == removed);
    Budget long_run;
    for (unsigned minute = 0; minute != 600; ++minute) {
        for (unsigned i = 0; i != 64; ++i) assert(long_run.take(minute, 64) == 1);
        assert(long_run.take(minute, 64) == 2);
        for (unsigned i = 0; i != 100; ++i) assert(long_run.take(minute, 64) == 0);
        if (minute) assert(long_run.take(minute - 1, 64) == 0);
    }
    Budget simultaneous;
    std::atomic<unsigned> emitted{0}, markers{0};
    std::vector<std::thread> threads;
    for (unsigned i = 0; i != 8; ++i) threads.emplace_back([&] {
        for (unsigned j = 0; j != 1000; ++j) {
            const auto decision = simultaneous.take(42, 64);
            if (decision == 1) ++emitted;
            if (decision == 2) ++markers;
        }
    });
    for (auto& t : threads) t.join();
    assert(emitted == 64 && markers == 1);
    assert(simultaneous.take(43, 64) == 1);
    Budget separate;
    assert(separate.take(42, 64) == 1);
    puts("PASS: 600 minute renewals, stale timestamp, concurrent quota, independent channel, loss classification");
}
