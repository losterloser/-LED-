"""Check useful failure behavior, independent of a board or Vivado installation."""
from pathlib import Path
import json,runpy,tempfile,unittest

ROOT=Path(__file__).resolve().parents[2]
check=runpy.run_path(str(ROOT/'skill/fpga-audio-reproduce/scripts/check_reports.py'))['check_reports']

class ReportChecks(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.config={'timing_report':'timing.txt','utilization_report':'util.txt','check_timing_report':'checks.txt','maximum_resources':{'Slice LUTs':100}}
        (self.root/'timing.txt').write_text('WNS(ns) TNS(ns) TNSF TNST WHS(ns)\n-------------------------------\n0.379 0.000 0 10 0.025\n')
        (self.root/'util.txt').write_text('| Slice LUTs | 90 |\n')
        (self.root/'checks.txt').write_text('checking no_clock (0)\nchecking unconstrained_internal_endpoints (0)\n')
    def tearDown(self):self.temp.cleanup()
    def test_valid_reports(self):self.assertTrue(check(self.root,self.config)['passed'])
    def test_negative_setup_rejected(self):
        p=self.root/'timing.txt';p.write_text(p.read_text().replace('0.379','-0.001'));self.assertFalse(check(self.root,self.config)['passed'])
    def test_negative_hold_rejected(self):
        p=self.root/'timing.txt';p.write_text(p.read_text().replace('0.025','-0.002'));self.assertFalse(check(self.root,self.config)['passed'])
    def test_resource_budget_rejected(self):
        (self.root/'util.txt').write_text('| Slice LUTs | 101 |\n');self.assertFalse(check(self.root,self.config)['passed'])
    def test_missing_report_is_not_pass(self):
        (self.root/'checks.txt').unlink();self.assertFalse(check(self.root,self.config)['passed'])
    def test_unconstrained_endpoint_rejected(self):
        p=self.root/'checks.txt';p.write_text(p.read_text().replace('endpoints (0)','endpoints (1)'));self.assertFalse(check(self.root,self.config)['passed'])

if __name__=='__main__':unittest.main(verbosity=2)
