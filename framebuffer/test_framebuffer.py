# Written by dustin richmond at UCSC for CSE x25
import pytest
import os
import pytest_utils
#from pytest_utils.decorators import max_score, visibility, tags
  
from cocotb_test.simulator import run
import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.utils import get_sim_time
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, with_timeout, First, First
from cocotb.types import LogicArray
import json
import random
random.seed(42)

_DIR_PATH = os.path.dirname(os.path.realpath(__file__))
_MODULE=os.path.basename(_DIR_PATH)

# Utility functions for parsing the filelist. Each module directory
# must have filelist.json with keys for "top" and "files".
def get_files_from_filelist(n):
    n = os.path.join(_DIR_PATH, n)
    with open(n) as filelist:
        files = json.load(filelist)["files"]
    return files

def get_sources():
    sources = get_files_from_filelist("filelist.json")
    sources = [os.path.join(os.getenv('REPO_ROOT'), f) for f in sources]
    return sources

def get_top():
    return get_top_from_filelist("filelist.json")

def get_top_from_filelist(n):
    n = os.path.join(_DIR_PATH, n)
    with open(n) as filelist:
        top = json.load(filelist)["top"]
    return top

def get_param_string(parameters):
    return "_".join(("{}={}".format(*i) for i in parameters.items()))
   
timescale = "1ps/1ps"

def testbench_runner():
    parameters = {}   

    simulator = os.getenv('SIM').lower()
    # Note how the run/build paths change with parameterized tests.
    run_dir = os.path.join(_DIR_PATH, "run", simulator, get_param_string(parameters))
    sim_build = os.path.join(_DIR_PATH, "build", get_param_string(parameters))

    # Icarus doesn't build
    if simulator.startswith("icarus"):
        sim_build = run_dir

    if simulator.startswith("verilator"):
        compile_args=["-Wno-fatal", "--timing"]
        if(not os.path.exists(run_dir)):
            os.makedirs(run_dir)
    else:
        compile_args=[]

    run(
        verilog_sources=get_sources(),
        toplevel="testbench",
        module="test_" + _MODULE,
        defines=["COCOTB=1"],
        compile_args=compile_args,
        waves=True,
        timescale=timescale,
        sim_build=sim_build,
        work_dir=run_dir
    )

@cocotb.test()
async def run_test(dut):
    await First(RisingEdge(dut.error_o), RisingEdge(dut.pass_o))
    print(f"Cocotb saw: error_o: {dut.error_o.value}, pass_o: {dut.pass_o.value}")
