import glob
import os
import argparse

def extract_module(code, module_name):
    lines = code.split('\n')
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith(f'const {module_name} = {{'):
            start = i
            break
    if start is None:
        return None
    brace_count = 1  # Opening brace
    for i in range(start + 1, len(lines)):
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0:
            return '\n'.join(lines[start:i+1])
    return None

def extract_function(code, func_name):
    lines = code.split('\n')
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith(f'async function {func_name}() {{'):
            start = i
            break
    if start is None:
        return None
    brace_count = 1  # Opening brace
    end = None
    for i in range(start + 1, len(lines)):
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0:
            end = i
            break
    if end is None:
        return None
    extracted = '\n'.join(lines[start:end+1])
    # Check for the trailing call
    if end + 1 < len(lines) and lines[end + 1].strip() == 'initVoiceChat();':
        extracted += '\ninitVoiceChat();'
    return extracted

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Combine JavaScript files and optionally extract specific modules from client-side JS.')
parser.add_argument('--files', nargs='*', default=[], help='List of file paths to include entirely. If not specified, uses default files.')
parser.add_argument('--client-modules', nargs='*', default=[], help='List of module names to extract from voicechat.js (e.g., SocketManager, PeerManager, shared, init).')
args = parser.parse_args()

# Default files if none specified
default_files = [
    './webrtc/server\\state.js',
    './webrtc/server\\public\\voicechat.js'
]
files_to_include = args.files if args.files else default_files

# Client file path (hardcoded)
client_path = './webrtc/server\\public\\voicechat.js'

# Prepare the combined content
combined_content = """
/* 
this was prepared using a script to glue relevant project modules to the request together.
The name of each file/module is included in each header.
When modifying a module/file, inform the user which file you are modifying.
do not try to rebuild this combination, but instead focus on one module, per code block.
If it makes sense to put the request in a different/new module, please do so and inform the user you made a new module/using a differnt module.
*/\n"""

# Process whole files (excluding client if modules are specified)
for file_path in files_to_include:
    if file_path == client_path and args.client_modules:
        continue  # Skip whole client if extracting modules
    filename = os.path.basename(file_path)
    header = f'/* \n=============================\n{filename}\n=============================\n*/ \n'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    combined_content += header + content + '\n\n'

# Process client modules if specified
if args.client_modules:
    with open(client_path, 'r', encoding='utf-8') as f:
        client_code = f.read()
    lines = client_code.split('\n')
    module_names = ['SocketManager', 'PeerManager', 'AudioManager', 'VADManager', 'UIManager']
    first_module_index = next((i for i, line in enumerate(lines) if any(line.strip().startswith(f'const {m} = {{') for m in module_names)), None)
    shared_code = '\n'.join(lines[:first_module_index]) if first_module_index is not None else ''
    
    extracted = {}
    if 'shared' in args.client_modules:
        extracted['shared'] = shared_code
    for mod in set(args.client_modules) - {'shared', 'init'}:
        mod_code = extract_module(client_code, mod)
        if mod_code:
            extracted[mod] = mod_code
        else:
            print(f"Warning: Module '{mod}' not found in {client_path}")
    if 'init' in args.client_modules:
        init_code = extract_function(client_code, 'initVoiceChat')
        if init_code:
            extracted['init'] = init_code
        else:
            print(f"Warning: Function 'initVoiceChat' not found in {client_path}")
    
    for name, code in extracted.items():
        header = f'/* \n=============================\nvoicechat.js - {name}\n=============================\n*/ \n'
        combined_content += header + code + '\n\n'

# Write the combined content to a file in the current directory
output_file = 'combined.js'
with open(output_file, 'w', encoding='utf-8') as f:
    f.write(combined_content)

print(f"Combined JavaScript files into {output_file}")