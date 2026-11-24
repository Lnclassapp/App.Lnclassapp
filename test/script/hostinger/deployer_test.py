# Tests of script/hostinger/deployer.py (pure helpers). Run: python3 -I test/script/hostinger/deployer_test.py
import importlib.util, pathlib, unittest

path = pathlib.Path(__file__).resolve().parents[3] / "script" / "hostinger" / "deployer.py"
spec = importlib.util.spec_from_file_location("deployer", path)
deployer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployer)


class ParseEnvTest(unittest.TestCase):
    def test_ignores_blank_lines_and_comments(self):
        text = "# commentaire\n\nA=1\n   # indenté\nB='deux'\n#C=3\nD=a=b\n"
        self.assertEqual(deployer.parse_env(text), {"A": "1", "B": "deux", "D": "a=b"})


class MaskTest(unittest.TestCase):
    def test_masks_every_github_token_prefix(self):
        for prefix in ("github_pat_", "ghp_", "ghs_", "gho_", "ghu_", "ghr_"):
            self.assertEqual(deployer.mask(f"token {prefix}AbC123xyz fin"), "token [masqué] fin", prefix)

    def test_masks_credentials_in_urls(self):
        self.assertEqual(deployer.mask("postgres://user:secret@db/x"), "[masqué]db/x")

    def test_leaves_ordinary_lines(self):
        self.assertEqual(deployer.mask("ghost_town started"), "ghost_town started")


if __name__ == "__main__":
    unittest.main()
