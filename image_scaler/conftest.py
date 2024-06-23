# Written by dustin richmond at UCSC for CSE x25
def pytest_make_parametrize_id(config, val, argname):
    return f"{argname}={val}"
