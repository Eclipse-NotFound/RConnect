"""Root entry; requires final exact aggregate runtime freeze before any AIR."""
from native_inputs import verify_tools,paint_audit_log
from runtime_adapter import outer_source

def main():
    verify_tools()
    scope=dict(__file__=__file__,__name__='aggregate_early_native_adapter',paint_audit_log=paint_audit_log)
    exec(compile(outer_source(),__file__,'exec'),scope)
    scope['main']()

if __name__=='__main__':main()
