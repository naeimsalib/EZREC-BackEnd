#!/usr/bin/env python3
"""
Emergency fix for utils.py syntax error
Fixes the unterminated string literal in the execute_query method
"""

import sys
import os

def fix_utils_syntax(file_path):
    """Fix the syntax error in utils.py"""
    print(f"🔧 Fixing syntax error in {file_path}")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix the specific syntax error
        fixes = [
            # Fix unterminated string literals
            ('logger.warning(f"❌ Unsupported query format:\n{query}")', 'logger.warning(f"❌ Unsupported query format: {query}")'),
            ('logger.warning(f"❌ Only SELECT queries supported. Received:\n{query}")', 'logger.warning(f"❌ Only SELECT queries supported. Received: {query}")'),
            # Fix any other potential issues
            ('logger.warning(f"❌ Unsupported query format:\\n{query}")', 'logger.warning(f"❌ Unsupported query format: {query}")'),
            ('logger.warning(f"❌ Only SELECT queries supported. Received:\\n{query}")', 'logger.warning(f"❌ Only SELECT queries supported. Received: {query}")'),
        ]
        
        for old, new in fixes:
            content = content.replace(old, new)
        
        # Write back the fixed content
        with open(file_path, 'w') as f:
            f.write(content)
        
        print(f"✅ Fixed syntax error in {file_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error fixing {file_path}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 fix_utils_syntax.py <path_to_utils.py>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    success = fix_utils_syntax(file_path)
    sys.exit(0 if success else 1) 