"""Portable Vivado report checks. Configurable paths/limits; standard library only."""
from pathlib import Path
import argparse,json,re

def check_reports(root, config):
    root=Path(root).resolve();observed={};errors=[]
    def read(key):
        path=(root/config[key]).resolve()
        if not path.is_relative_to(root):raise ValueError('Report must remain inside the supplied root')
        return path.read_text(encoding='utf-8-sig',errors='replace')
    try:
        timing=read('timing_report')
        match=re.search(r'WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+([-\d.]+)',timing,re.S)
        if not match:raise ValueError('Setup/hold summary table missing')
        observed['setup_wns_ns'],observed['hold_whs_ns']=map(float,match.groups())
        for name in ('setup_wns_ns','hold_whs_ns'):
            if observed[name]<config.get('minimum_'+name,0):errors.append(name+' below required slack')
        utilization=read('utilization_report');observed['resources']={}
        for label,maximum in config.get('maximum_resources',{}).items():
            match=re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',utilization)
            if not match:raise ValueError('Resource row missing: '+label)
            value=float(match.group(1));observed['resources'][label]=value
            if value>maximum:errors.append(label+' exceeds configured budget')
        checks=read('check_timing_report')
        for label in config.get('zero_timing_checks',['no_clock','unconstrained_internal_endpoints']):
            match=re.search(r'checking '+re.escape(label)+r' \((\d+)\)',checks)
            if not match or int(match.group(1)):errors.append(label+' check missing or nonzero')
        if config.get('bus_skew_report'):
            skew=read('bus_skew_report');slacks=[float(x) for x in re.findall(r'Slack \(MET\)\s*:\s*([-\d.]+)ns',skew)]
            if not slacks or min(slacks)<0 or 'VIOLATED' in skew:errors.append('Bus skew has not passed')
            observed['minimum_bus_skew_slack_ns']=min(slacks) if slacks else None
    except (OSError,ValueError) as exc:errors.append(str(exc))
    return {'passed':not errors,'observed':observed,'errors':errors}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--config',type=Path,required=True);a=p.parse_args()
    result=check_reports(a.root,json.loads(a.config.read_text(encoding='utf-8')));print(json.dumps(result,ensure_ascii=False,indent=2));raise SystemExit(0 if result['passed'] else 1)
