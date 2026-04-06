# Cordys CRM Skills API Alignment Log

## Scope

This update aligns the skill scripts with the actual Cordys CRM API behavior and the new backend compatibility layer.

## Modified Files

- `README.md`
- `skills/scripts/cordys.js`
- `skills/scripts/cordys.py`
- `skills/scripts/cordys.sh`

## Functional Changes

### 1. Script alignment

Aligned all three script implementations to the CRM API:

- Python: `skills/scripts/cordys.py`
- Node.js: `skills/scripts/cordys.js`
- Bash: `skills/scripts/cordys.sh`

### 2. Request behavior fixes

- `raw` now forwards the request body correctly
- `page` uses the actual module page API shape
- `search` uses the global search API consistently
- `org` and module metadata calls match the backend routes

### 3. Windows compatibility

Fixed shell behavior for Git Bash on Windows:

- `cordys.sh` now prefers a usable `python` executable over the broken `python3` WindowsApps stub
- this fixes empty payload generation for `crm page` and similar commands

### 4. Documentation update

Updated README environment variable examples to the actual names used by the scripts:

- `CORDYS_CRM_DOMAIN`
- `CORDYS_ACCESS_KEY`
- `CORDYS_SECRET_KEY`

## Validation

### Static checks

Executed successfully:

- `python -m py_compile skills/scripts/cordys.py`
- `node --check skills/scripts/cordys.js`

### Runtime checks

Executed successfully against a local Cordys CRM instance:

- `python skills/scripts/cordys.py raw GET /settings/fields?module=account`
- `python skills/scripts/cordys.py crm page lead`
- `node skills/scripts/cordys.js crm org`
- `node skills/scripts/cordys.js raw GET /contact/module/form`
- `bash skills/scripts/cordys.sh raw GET /contact/module/form`
- `bash skills/scripts/cordys.sh crm page lead`

## Notes

- The scripts are now aligned with the backend compatibility changes pushed to the companion `CordysCRM` repository.
