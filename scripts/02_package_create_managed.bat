REM *****************************
REM        PACKAGE CREATION   
REM *****************************

REM Package Create Config
SET devHub=devHubAlias
SET packageName=MCP App Bridge
SET packageDescription=A flexible, configuration-driven bridge that exposes Lightning Web Components as MCP Apps through Lightning Out 2.0 and a native Apex REST MCP server.
SET packageType=Managed
SET packagePath=force-app
SET definitionFile=config/project-scratch-def.json

REM Package Config
SET packageId=0HoP3000000021pKAA
SET packageVersionId=04tP3000002Dt5ZIAS

REM Prevent protected sample records or locked App ID configuration from entering a package version.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Validate-PackageMetadata.ps1"
IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM The package already exists. Run this once only when establishing a new Dev Hub/package:
REM sf package create --name "%packageName%" --description "%packageDescription%" --package-type "%packageType%" --path "%packagePath%" --target-dev-hub %devHub%

REM Create package version
sf package version create --package "%packageName%"  --target-dev-hub "%devHub%" --code-coverage --installation-key-bypass --wait 30 --definition-file "%definitionFile%"

REM Optional lifecycle command reference - run separately when deliberately required:
REM sf package delete --package %packageId% --target-dev-hub %devHub% --no-prompt
REM sf package version delete --package %packageVersionId% --target-dev-hub %devHub% --no-prompt
REM sf package version promote --package %packageVersionId% --target-dev-hub %devHub% --no-prompt

REM /packaging/installPackage.apexp?p0=04tP3000002Dt5ZIAS
