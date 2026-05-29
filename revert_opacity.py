import os
import re

def replace_with_opacity(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Regex to find .withValues(alpha: 0.1) and replace with .withOpacity(0.1)
                # It handles different spacing and values
                new_content = re.sub(r'\.withValues\(alpha:\s*([\d\.]+)\)', r'.withOpacity(\1)', content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated: {path}")

if __name__ == "__main__":
    replace_with_opacity('lib')
