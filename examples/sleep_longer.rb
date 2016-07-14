#!/usr/bin/env ruby

require "abprof"

ABProf::ABWorker.iteration do
  sleep 0.0015
end

ABProf::ABWorker.start
