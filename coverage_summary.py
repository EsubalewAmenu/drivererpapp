import sys
import os

def check_coverage(file_path, target_files):
    if not os.path.exists(file_path):
        print(f"Coverage file not found: {file_path}")
        return

    coverage = {}
    current_file = None
    lines_hit = 0
    lines_found = 0

    with open(file_path, 'r') as f:
        for line in f:
            if line.startswith('SF:'):
                current_file = line.strip().split('SF:')[1]
                # Normalize path
                if current_file.startswith('/'):
                    # Try to find lib relative path
                    if 'lib/' in current_file:
                        current_file = 'lib/' + current_file.split('lib/')[1]
                lines_hit = 0
                lines_found = 0
            elif line.startswith('DA:'):
                lines_found += 1
                if int(line.strip().split(',')[1]) > 0:
                    lines_hit += 1
            elif line.startswith('end_of_record'):
                if current_file:
                    coverage[current_file] = (lines_hit, lines_found)

    print(f"{'File':<60} | {'Coverage':<10} | {'Hit/Total'}")
    print("-" * 85)
    
    for target in target_files:
        # Match target in coverage (exact or relative)
        matches = [f for f in coverage if target in f]
        if matches:
            for match in matches:
                hit, total = coverage[match]
                percentage = (hit / total * 100) if total > 0 else 0
                print(f"{match:<60} | {percentage:>9.2f}% | {hit}/{total}")
        else:
            print(f"{target:<60} | {'0.00%':>10} | 0/0")

if __name__ == "__main__":
    targets = [
        'lib/providers/schema_provider.dart',
        'lib/screens/dynamic_form/dynamic_form_renderer.dart',
        'lib/screens/module_screen.dart',
        'lib/screens/schema_editor/structure_editor.dart',
        'lib/services/drive/drive_sheet_mixin.dart',
        'lib/screens/schema_editor/dialogs/edit_setting_dialog.dart',
        'lib/models/schema_models.g.dart',
        'lib/providers/drive_provider.dart',
        'lib/screens/module/module_tab_screen.dart',
        'lib/screens/record_detail_screen.dart',
        'lib/screens/dynamic_form/fields/dropdown_field.dart'
    ]
    check_coverage('coverage/lcov.info', targets)
