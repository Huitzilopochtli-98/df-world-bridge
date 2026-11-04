from pathlib import Path
import hashlib,json,struct,sys,tempfile,unittest,zlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import package_workshop as pack

def png(width=256,height=256):
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+b'\0'*(width*3))*height))+chunk(b'IEND',b'')

class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='world-bridge-workshop-')
        self.root=Path(self.temp.name).resolve()
        assert self.root.parent==Path(tempfile.gettempdir()).resolve()
        self.preview=self.root/'preview.png';self.preview.write_bytes(png())
    def tearDown(self):self.temp.cleanup()
    def test_complete_runtime_and_source_integrity(self):
        folder,archive=pack.build(self.root/'out',self.preview)
        self.assertTrue(archive.is_file())
        for path in (ROOT/'lua').rglob('*.lua'):
            self.assertEqual(path.read_bytes(),(folder/path.relative_to(ROOT)).read_bytes())
        main=(folder/'scripts_modinstalled/world-bridge.lua').read_text()
        self.assertLess(main.index('--@enable'),main.index(pack.PRELUDE))
        self.assertLess(main.index(pack.PRELUDE),main.index("require('world-bridge.df-adapter')"))
        self.assertIn('[ID:world_bridge]',(folder/'info.txt').read_text())
        self.assertIn('No manual', (folder/'README.md').read_text().replace('does not need the\nPowerShell installer','No manual'))
        self.assertEqual('MIT',json.loads((folder/'SOURCE.json').read_text())['license'])
        for line in (folder/'SHA256SUMS.txt').read_text().splitlines():
            digest,name=line.split('  ',1)
            self.assertEqual(digest,hashlib.sha256((folder/name).read_bytes()).hexdigest())
        self.assertFalse(any(p.suffix.lower() in ('.dll','.exe','.sav','.dat','.ps1') for p in folder.rglob('*')))
    def test_existing_output_preserves_item_id(self):
        output=self.root/'out';folder,_=pack.build(output,self.preview)
        info=folder/'info.txt';info.write_text(info.read_text()+'\n[STEAM_FILE_ID:123]\n')
        with self.assertRaises(ValueError):pack.build(output,self.preview)
        self.assertIn('[STEAM_FILE_ID:123]',info.read_text())
    def test_invalid_preview_creates_nothing(self):
        self.preview.write_bytes(b'not a PNG')
        with self.assertRaises(ValueError):pack.build(self.root/'out',self.preview)
        self.assertFalse((self.root/'out').exists())
    def test_small_preview_rejected(self):
        self.preview.write_bytes(png(64,64))
        with self.assertRaises(ValueError):pack.build(self.root/'out',self.preview)

if __name__=='__main__':unittest.main()
