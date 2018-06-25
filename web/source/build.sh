#! /bin/bash
# 
# Compile keymanweb and copy compiled javascript and resources to output/embedded folder
#

display_usage ( ) {
    echo "build.sh [-ui | -test | -embed | -web | -debug_embedded] [-no_minify] [-clean]"
    echo
    echo "  -ui               to compile desktop user interface modules to output folder"
    echo "  -test             to compile for testing without copying resources or" 
    echo "                    updating the saved version number."
    echo "  -embed            to compile only the KMEA/KMEI embedded engine."
    echo "  -web              to compile only the KeymanWeb engine."
    echo "  -debug_embedded   to compile a readable version of the embedded KMEA/KMEI code"
    echo "  -no_minify        to disable the minification '/release/' build sections -"  
    echo "                      the '/release/unminified' subfolders will still be built."
    echo "  -clean            to erase pre-existing build products before the build."
    echo ""
    echo "  If more than one target is specified, the last one will take precedence."
    exit 1
}

# Fails the build if a specified file does not exist.
assert ( ) {
    if ! [ -f $1 ]; then
        fail "Build failed."
        exit 1
    fi
}

fail() {
    FAILURE_MSG="$1"
    if [[ "$FAILURE_MSG" == "" ]]; then
        FAILURE_MSG="Unknown failure"
    fi
    echo "${ERROR_RED}$FAILURE_MSG${NORMAL}"
    exit 1
}

# Build products for each main target.
WEB_TARGET=( "keymanweb.js" )
UI_TARGET=( "kmwuibutton.js" "kmwuifloat.js" "kmwuitoggle.js" "kmwuitoolbar.js" )
EMBED_TARGET=( "keyman.js" )

# Ensure the dependencies are downloaded.  --no-optional should help block fsevents warnings.
echo "Node.js + dependencies check"
npm install --no-optional

if [ $? -ne 0 ]; then
    fail "Build environment setup error detected!  Please ensure Node.js is installed!"
fi

: ${CLOSURECOMPILERPATH:=../node_modules/google-closure-compiler}
: ${JAVA:=java}

minifier="$CLOSURECOMPILERPATH/compiler.jar"
# We'd love to add the argument --source_map_include_content for distribution in the future,
# but Closure doesn't include the TS sources properly at this time.
#
# `checkTypes` is blocked b/c TypeScript can perform our type checking... and it causes an error
# with TypeScript's `extend` implementation (it doesn't recognize a constructor without manual edits).
# We also get a global `this` warning from the same.
#
# `checkVars` is blocked b/c Closure will otherwise fail on TypeScript namespacing, as each original TS 
# source file will redeclare the namespace variable, despite being merged into a single file post-compilation.
minifier_warnings="--jscomp_error=* --jscomp_off=lintChecks --jscomp_off=unusedLocalVariables --jscomp_off=globalThis --jscomp_off=checkTypes --jscomp_off=checkVars"
minifycmd="$JAVA -jar $minifier $minifier_warnings --generate_exports"

if ! [ -f $minifier ];
then
    echo File $minifier does not exist:  have you set the environment variable \$CLOSURECOMPILERPATH?
    exit 1
fi

readonly minifier
readonly minifycmd

# $1 - base file name
# $2 - output path
# $3 - optimization level
# $4 - defines
# $5 - additional output wrapper
minify ( ) {
    if [ "$4" ]; then
        defines="--define $4"
    else
        defines=
    fi

    if [ "$5" ]; then
        wrapper=$5
    else
        wrapper="%output%"
    fi

    $minifycmd $defines --source_map_input "$INTERMEDIATE/$1|$INTERMEDIATE/$1.map" \
        --create_source_map $2/$1.map --js $INTERMEDIATE/$1 --compilation_level $3 \
        --js_output_file $2/$1 --warning_level VERBOSE --output_wrapper "$wrapper
//# sourceMappingURL=$1.map"
}

# $1 - target (WEB, EMBEDDED)
# $2+ - build target array (one of WEB_TARGET, FULL_WEB_TARGET, or EMBED_TARGET)
finish_nominify ( ) {
    args=("$@")
    if [ $1 = $WEB ] || [ $1 = $UI ]; then
        dest=$WEB_OUTPUT_NO_MINI
        resourceDest=$dest
    else
        dest=$EMBED_OUTPUT_NO_MINI
        resourceDest=$dest/resources
    fi

    # Create our entire embedded compilation results path.
    if ! [ -d $dest ]; then
        mkdir -p "$dest"  # Includes base folder, is recursive.
    fi
    echo "Copying unminified $1 build products to $dest."

    for (( n=1; n<$#; n++ ))  # Apparently, args ends up zero-based, meaning $2 => n=1.
    do
        target=${args[$n]}
        cp -f $INTERMEDIATE/$target $dest/$target
        cp -f $INTERMEDIATE/$target.map $dest/$target.map
    done

    copy_resources $resourceDest
}

copy_resources ( ) {
    echo 
    echo Copy resources to $1/ui, .../osk

    # Create our entire compilation results path.  Can't one-line them due to shell-script parsing errors.
    if ! [ -d $1/ui ];      then 
        mkdir -p "$1/ui"      
    fi
    if ! [ -d $1/osk ];     then 
        mkdir -p "$1/osk"     
    fi
    if ! [ -d $1/src/ui ];  then 
        mkdir -p "$1/src/ui"  
    fi
    if ! [ -d $1/src/osk ]; then 
        mkdir -p "$1/src/osk" 
    fi

    cp -Rf $SOURCE/resources/ui  $1/  >/dev/null
    cp -Rf $SOURCE/resources/osk $1/  >/dev/null

    echo Copy source to $1/src
    cp -Rf $SOURCE/*.js $1/src
    cp -Rf $SOURCE/*.ts $1/src
    echo $BUILD > $1/src/version.txt

    # Remove KMW Recorder source.
    rm -f $1/src/recorder_*.ts
    rm -f $1/src/recorder_*.js

    cp -Rf $SOURCE/resources/ui  $1/src/ >/dev/null
    cp -Rf $SOURCE/resources/osk $1/src/ >/dev/null

    # Update build number if successful
    echo
    echo KeymanWeb resources saved under $1
    echo
}

clean ( ) {
    rm -rf "../release"
    rm -rf "../intermediate"
}

# Definition of global compile constants
UI="ui"
WEB="web"
EMBEDDED="embedded"

WEB_OUTPUT="../release/web"
EMBED_OUTPUT="../release/embedded"
WEB_OUTPUT_NO_MINI="../release/unminified/web"
EMBED_OUTPUT_NO_MINI="../release/unminified/embedded"
INTERMEDIATE="../intermediate"
SOURCE="."
NODE_SOURCE="source"

readonly WEB_OUTPUT
readonly EMBED_OUTPUT
readonly SOURCE

# Get build version -- if not building in TeamCity, then always use 300
: ${BUILD_COUNTER:=300}
BUILD=$BUILD_COUNTER

readonly BUILD

# Ensures that we rely first upon the local npm-based install of Typescript.
# (Facilitates automated setup for build agents.)
PATH="../node_modules/.bin:$PATH"

compiler="npm run tsc --"
compilecmd="$compiler"

# Establish default build parameters
set_default_vars ( ) {
    BUILD_UI=true
    BUILD_EMBED=true
    BUILD_FULLWEB=true
    BUILD_DEBUG_EMBED=false
    BUILD_COREWEB=true
    DO_MINIFY=true
}

if [[ $# = 0 ]]; then
    FULL_BUILD=true
else
    FULL_BUILD=false
fi

set_default_vars

# Parse args
while [[ $# -gt 0 ]] ; do
    key="$1"
    case $key in
        -ui)
            set_default_vars
            BUILD_EMBED=false
            BUILD_FULLWEB=false
            BUILD_COREWEB=false
            ;;
        -test)
            set_default_vars
            BUILD_TEST=true
            BUILD_UI=false
            BUILD_EMBED=false
            BUILD_FULLWEB=false
            ;;
        -embed)
            set_default_vars
            BUILD_FULLWEB=false
            BUILD_UI=false
            BUILD_COREWEB=false
            ;;
        -web)
            set_default_vars
            BUILD_EMBED=false
            ;;
        -debug_embedded)
            set_default_vars
            BUILD_EMBED=false
            BUILD_UI=false
            BUILD_COREWEB=false
            BUILD_FULLWEB=false
            BUILD_DEBUG_EMBED=true
            DO_MINIFY=false
            ;;
        -h|-?)
            display_usage
            ;;
        -no_minify)
            DO_MINIFY=false
            ;;
        -clean)
            clean
            ;;
    esac
    shift # past argument
done

readonly BUILD_UI
readonly BUILD_EMBED
readonly BUILD_FULLWEB
readonly BUILD_DEBUG_EMBED
readonly BUILD_COREWEB
readonly DO_MINIFY

if [ $FULL_BUILD = true ]; then
    echo Compiling build $BUILD
    echo ""
fi


if [ $BUILD_EMBED = true ] || [ $BUILD_DEBUG_EMBED = true ]; then
    echo Compile KMEI/KMEA build $BUILD

    $compilecmd -p $NODE_SOURCE/tsconfig.embedded.json
    if [ $? -ne 0 ]; then
        fail "Typescript compilation failed."
    fi
    assert $INTERMEDIATE/keyman.js
    echo Embedded TypeScript compiled as $INTERMEDIATE/keyman.js

    copy_resources "$INTERMEDIATE"  # Very useful for local testing.

    finish_nominify $EMBEDDED $EMBED_TARGET

    if [ $DO_MINIFY = true ]; then
        # Create our entire embedded compilation results path.
        if ! [ -d $EMBED_OUTPUT/resources ]; then
            mkdir -p "$EMBED_OUTPUT/resources"  # Includes base folder, is recursive.
        fi

        rm $EMBED_OUTPUT/keyman.js 2>/dev/null

        minify keyman.js $EMBED_OUTPUT SIMPLE_OPTIMIZATIONS "KeymanBase.__BUILD__=$BUILD"
        assert $EMBED_OUTPUT/keyman.js
        echo Compiled embedded application saved as $EMBED_OUTPUT/keyman.js

        # Update any changed resources
        # echo Copy or update resources

        copy_resources "$EMBED_OUTPUT/resources"

        # Update build number if successful
        echo
        echo KMEA/KMEI build $BUILD compiled and saved under $EMBED_OUTPUT
        echo
    fi
fi

if [ $BUILD_COREWEB = true ]; then
    # Compile KeymanWeb code modules for native keymanweb use, stubbing out and removing references to debug functions
    echo Compile Keymanweb...
    $compilecmd -p $NODE_SOURCE/tsconfig.web.json
    if [ $? -ne 0 ]; then
        fail "Typescript compilation failed."
    fi
    assert $INTERMEDIATE/keymanweb.js
    echo Native TypeScript compiled as $INTERMEDIATE/keymanweb.js

    copy_resources "$INTERMEDIATE"

    finish_nominify $WEB $WEB_TARGET

    if [ $DO_MINIFY = true ]; then
        rm $WEB_OUTPUT/keymanweb.js 2>/dev/null

        echo Minifying KeymanWeb...
        minify keymanweb.js $WEB_OUTPUT SIMPLE_OPTIMIZATIONS "KeymanBase.__BUILD__=$BUILD"
        assert $WEB_OUTPUT/keymanweb.js

        echo Compiled KeymanWeb application saved as $WEB_OUTPUT/keymanweb.js
    fi
fi

if [ $BUILD_FULLWEB = true ] && [ $DO_MINIFY = true ]; then
    copy_resources "$WEB_OUTPUT"
    # Update build number if successful
    echo
    echo KeymanWeb 2 build $BUILD compiled and saved under $WEB_OUTPUT
    echo
fi

if [ $BUILD_UI = true ]; then
    echo Compile UI Modules...
    $compilecmd -p $NODE_SOURCE/tsconfig.ui.json
    assert $INTERMEDIATE/kmwuitoolbar.js
    assert $INTERMEDIATE/kmwuitoggle.js
    assert $INTERMEDIATE/kmwuifloat.js
    assert $INTERMEDIATE/kmwuibutton.js

    finish_nominify $UI "${UI_TARGET[@]}"

    echo \'Native\' UI TypeScript has been compiled into the $INTERMEDIATE/ folder 

    if [ $DO_MINIFY = true ]; then
        echo Minify ToolBar UI
        del $WEB_OUTPUT/kmuitoolbar.js 2>/dev/null
        minify kmwuitoolbar.js $WEB_OUTPUT ADVANCED_OPTIMIZATIONS "" "(function() {%output%}());"
        assert $WEB_OUTPUT/kmwuitoolbar.js

        echo Minify Toggle UI
        del $WEB_OUTPUT/kmuitoggle.js 2>/dev/null
        minify kmwuitoggle.js $WEB_OUTPUT SIMPLE_OPTIMIZATIONS "" "(function() {%output%}());"
        assert $WEB_OUTPUT/kmwuitoggle.js

        echo Minify Float UI
        del $WEB_OUTPUT/kmuifloat.js 2>/dev/null
        minify kmwuifloat.js $WEB_OUTPUT ADVANCED_OPTIMIZATIONS "" "(function() {%output%}());"
        assert $WEB_OUTPUT/kmwuifloat.js

        echo Minify Button UI
        del $WEB_OUTPUT/kmuibutton.js 2>/dev/null
        minify kmwuibutton.js $WEB_OUTPUT SIMPLE_OPTIMIZATIONS "" "(function() {%output%}());"
        assert $WEB_OUTPUT/kmwuibutton.js

        echo "User interface modules compiled and saved under $WEB_OUTPUT"
    fi
fi

if [ $BUILD_DEBUG_EMBED = true ]; then
    # Copy the sourcemap.
    cp $INTERMEDIATE/keyman.js $EMBED_OUTPUT/keyman.js
    cp $INTERMEDIATE/keyman.js.map $EMBED_OUTPUT/keyman.js.map
    echo Uncompiled embedded application saved as $EMBED_OUTPUT/keyman.js
fi
