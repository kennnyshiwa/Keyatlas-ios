#!/usr/bin/env python3
"""Execute the production Swift import/error DTOs against backend wire fixtures."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
view = (root / 'Sources/KeyAtlas/Views/Submission/ProjectSubmissionView.swift').read_text()
api = (root / 'Sources/KeyAtlas/Services/APIClient.swift').read_text()
response = view[view.index('private struct URLImportResponse:'):view.index('// MARK: - Vendor Entry')]
error = api[api.index('struct ErrorResponse:'):api.index('struct ValidationError:')]
fixture = r'''
let payload = #"{"title":"Fixture","category":"KEYCAPS","gbStartDate":"2026-09-11","gbEndDate":"2026-10-11","links":[{"label":"Geekhack","url":"https://geekhack.org/index.php?topic=1.0"}],"images":[{"url":"https://example.com/image.jpg","alt":"Kit"}]}"#.data(using: .utf8)!
let imported = try JSONDecoder().decode(URLImportResponse.self, from: payload)
precondition(imported.images?.count == 1)
precondition(imported.images?.first?.alt == "Kit")
precondition(imported.gbStartDate == "2026-09-11")
precondition(imported.gbEndDate == "2026-10-11")
precondition(imported.links?.first?.title == "Geekhack")
let empty = try JSONDecoder().decode(URLImportResponse.self, from: Data("{}".utf8))
precondition(empty.images == nil)
let encoded = try JSONEncoder().encode(imported.images!)
precondition(try JSONDecoder().decode([URLImportResponse.ImportedImage].self, from: encoded) == imported.images!)
let denied = try JSONDecoder().decode(ErrorResponse.self, from: Data(#"{"error":"Unauthorized"}"#.utf8))
precondition((denied.message ?? denied.error) == "Unauthorized")
print("Submission wire-contract checks passed")
'''
# Throwing calls must evaluate before precondition's nonthrowing autoclosure.
fixture = fixture.replace('precondition(try JSONDecoder().decode([URLImportResponse.ImportedImage].self, from: encoded) == imported.images!)', 'let roundTrip = try JSONDecoder().decode([URLImportResponse.ImportedImage].self, from: encoded)\nprecondition(roundTrip == imported.images!)')
with tempfile.TemporaryDirectory() as tmp:
    source = Path(tmp) / 'main.swift'
    source.write_text('import Foundation\n' + response + error + 'do {\n' + fixture + '\n}')
    subprocess.run(['swift', str(source)], check=True)
