"""Use the exact frozen profile validity checker; no performance qualification."""
from binding import V1,load,verify_tools

prior=load('frozen_paint_driver_v1_profile_audit',V1/'audit_profile.py')
audit_profiles=prior.audit_profiles
audit_log=prior.audit_log

def main():
    verify_tools()
    prior.main()

if __name__=='__main__':main()
