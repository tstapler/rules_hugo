function _interopDefault (ex) { return (ex && (typeof ex === 'object') && 'default' in ex) ? ex['default'] : ex; }

var path = _interopDefault(require('path'));
var SingleEntryPlugin = _interopDefault(require('webpack/lib/SingleEntryPlugin'));
var MultiEntryPlugin = _interopDefault(require('webpack/lib/MultiEntryPlugin'));
var os = _interopDefault(require('os'));
var jsdom = _interopDefault(require('jsdom'));
var loaderUtils = _interopDefault(require('loader-utils'));
var LibraryTemplatePlugin = _interopDefault(require('webpack/lib/LibraryTemplatePlugin'));
var NodeTemplatePlugin = _interopDefault(require('webpack/lib/node/NodeTemplatePlugin'));
var NodeTargetPlugin = _interopDefault(require('webpack/lib/node/NodeTargetPlugin'));
var webpack = require('webpack');
var MemoryFs = _interopDefault(require('memory-fs'));

function runChildCompiler(compiler) {
    return new Promise(function (resolve, reject) {
        compiler.compile(function (err, compilation) {
            compiler.parentCompilation.children.push(compilation);
            if (err) 
                { return reject(err); }
            if (compilation.errors && compilation.errors.length) {
                var errorDetails = compilation.errors.map(function (error) { return error.details; }).join('\n');
                return reject(Error('Child compilation failed:\n' + errorDetails));
            }
            resolve(compilation);
        });
    });
}

function getRootCompiler(compiler) {
    while (compiler.parentCompilation && compiler.parentCompilation.compiler) {
        compiler = compiler.parentCompilation.compiler;
    }
    return compiler;
}

function getBestModuleExport(exports) {
    if (exports.default) {
        return exports.default;
    }
    for (var prop in exports) {
        if (prop !== '__esModule') {
            return exports[prop];
        }
    }
}

function stringToModule(str) {
    return 'export default ' + JSON.stringify(str);
}

function convertPathToRelative(context, entry, prefix) {
    if ( prefix === void 0 ) prefix = '';

    if (Array.isArray(entry)) {
        return entry.map(function (entry) { return prefix + path.relative(context, entry); });
    } else if (entry && typeof entry === 'object') {
        return Object.keys(entry).reduce(function (acc, key) {
            acc[key] = Array.isArray(entry[key]) ? entry[key].map(function (item) { return prefix + path.relative(context, item); }) : prefix + path.relative(context, entry[key]);
            return acc;
        }, {});
    }
    return prefix + path.relative(context, entry);
}

function applyEntry(context, entry, compiler) {
    if (typeof entry === 'string' || Array.isArray(entry)) {
        itemToPlugin(context, entry, 'main').apply(compiler);
    } else if (typeof entry === 'object') {
        Object.keys(entry).forEach(function (name) {
            itemToPlugin(context, entry[name], name).apply(compiler);
        });
    }
}

function itemToPlugin(context, item, name) {
    if (Array.isArray(item)) {
        return new MultiEntryPlugin(context, item, name);
    }
    return new SingleEntryPlugin(context, item, name);
}

var PLUGIN_NAME = 'prerender-loader';
var FILENAME = 'ssr-bundle.js';
var PRERENDER_REG = /\{\{prerender(?::\s*([^}]+?)\s*)?\}\}/;
function PrerenderLoader(content) {
    var options = loaderUtils.getOptions(this) || {};
    var outputFilter = options.as === 'string' || options.string ? stringToModule : String;
    if (options.disabled === true) {
        return outputFilter(content);
    }
    var inject = false;
    if (!this.request.match(/.(js|ts)x?$/i)) {
        var matches = content.match(PRERENDER_REG);
        if (matches) {
            inject = true;
            options.entry = matches[1];
        }
        options.templateContent = content;
    }
    var callback = this.async();
    prerender(this._compilation, this.request, options, inject, this).then(function (output) {
        callback(null, outputFilter(output));
    }).catch(function (err) {
        callback(err);
    });
}

function prerender(parentCompilation, request, options, inject, loader) {
    return new Promise(function ($return, $error) {
        var parentCompiler, context, customEntry, entry, outputOptions, allowedPlugins, plugins, compiler, subCache, compilation, output, tpl, injectPlaceholder, template, content, parent;
        var result, dom, window, injectParent, injectNextSibling, serialized;
        function addChildCache(compilation, data) {
            if (compilation.cache) {
                if (!compilation.cache[subCache]) 
                    { compilation.cache[subCache] = {}; }
                compilation.cache = compilation.cache[subCache];
            }
        }
        
        function BrokenPromise() {}
        
        parentCompiler = getRootCompiler(parentCompilation.compiler);
        context = parentCompiler.options.context || process.cwd();
        customEntry = options.entry && ([].concat(options.entry).pop() || '').trim();
        entry = customEntry ? './' + customEntry : convertPathToRelative(context, parentCompiler.options.entry, './');
        outputOptions = {
            path: os.tmpdir(),
            filename: FILENAME
        };
        allowedPlugins = /(MiniCssExtractPlugin|ExtractTextPlugin)/i;
        plugins = (parentCompiler.options.plugins || []).filter(function (c) { return allowedPlugins.test(c.constructor.name); });
        compiler = parentCompilation.createChildCompiler('prerender', outputOptions, plugins);
        compiler.context = parentCompiler.context;
        compiler.outputFileSystem = new MemoryFs();
        new webpack.DefinePlugin({
            PRERENDER: 'true'
        }).apply(compiler);
        new webpack.DefinePlugin({
            PRERENDER: 'false'
        }).apply(parentCompiler);
        new NodeTemplatePlugin(outputOptions).apply(compiler);
        new NodeTargetPlugin().apply(compiler);
        new LibraryTemplatePlugin('PRERENDER_RESULT', 'var').apply(compiler);
        applyEntry(context, entry, compiler);
        subCache = 'subcache ' + request;
        if (compiler.hooks) {
            compiler.hooks.compilation.tap(PLUGIN_NAME, addChildCache);
        } else {
            compiler.plugin('compilation', addChildCache);
        }
        return runChildCompiler(compiler).then((function ($await_3) {
            try {
                compilation = $await_3;
                BrokenPromise.prototype.then = (BrokenPromise.prototype.catch = (BrokenPromise.prototype.finally = (function () { return new BrokenPromise(); })));
                if (compilation.assets[compilation.options.output.filename]) {
                    output = compilation.assets[compilation.options.output.filename].source();
                    tpl = options.templateContent || '<!DOCTYPE html><html><head></head><body></body></html>';
                    dom = new jsdom.JSDOM(tpl.replace(PRERENDER_REG, '<div id="PRERENDER_INJECT"></div>'), {
                        virtualConsole: new jsdom.VirtualConsole({
                            omitJSDOMErrors: false
                        }).sendTo(console),
                        url: options.documentUrl || 'http://localhost',
                        includeNodeLocations: false,
                        runScripts: 'outside-only'
                    });
                    window = dom.window;
                    injectPlaceholder = window.document.getElementById('PRERENDER_INJECT');
                    if (injectPlaceholder) {
                        injectParent = injectPlaceholder.parentNode;
                        injectNextSibling = injectPlaceholder.nextSibling;
                        injectPlaceholder.remove();
                    }
                    var counter = 0;
                    window.requestAnimationFrame = (function () { return ++counter; });
                    window.cancelAnimationFrame = (function () {});
                    window.customElements = {
                        define: function define() {},
                        get: function get() {},
                        upgrade: function upgrade() {},
                        whenDefined: function () { return new BrokenPromise(); }
                    };
                    window.MessagePort = function () {
                        (this.port1 = new window.EventTarget()).postMessage = (function () {});
                        (this.port2 = new window.EventTarget()).postMessage = (function () {});
                    };
                    window.matchMedia = (function () { return ({
                        addListener: function addListener() {}
                    }); });
                    if (!window.navigator) 
                        { window.navigator = {}; }
                    window.navigator.serviceWorker = {
                        register: function () { return new BrokenPromise(); }
                    };
                    window.PRERENDER = true;
                    window.require = (function (moduleId) {
                        var asset = compilation.assets[moduleId.replace(/^\.?\//g, '')];
                        if (!asset) {
                            try {
                                return require(moduleId);
                            } catch (e) {
                                throw Error(("Error:  Module not found. attempted require(\"" + moduleId + "\")"));
                            }
                        }
                        var mod = {
                            exports: {}
                        };
                        window.eval(("(function(exports, module, require){\n" + (asset.source()) + "\n})"))(mod.exports, mod, window.require);
                        return mod.exports;
                    });
                    result = window.eval(output + '\nPRERENDER_RESULT');
                }
                if (result && typeof result === 'object') {
                    result = getBestModuleExport(result);
                }
                if (typeof result === 'function') {
                    result = result(options.params || null);
                }
                if (result && result.then) {
                    return result.then((function ($await_4) {
                        try {
                            result = $await_4;
                            return $If_2.call(this);
                        } catch ($boundEx) {
                            return $error($boundEx);
                        }
                    }).bind(this), $error);
                }
                function $If_2() {
                    if (result !== undefined && options.templateContent) {
                        template = window.document.createElement('template');
                        template.innerHTML = result || '';
                        content = template.content || template;
                        parent = injectParent || window.document.body;
                        var child;
                        while (child = content.firstChild) {
                            parent.insertBefore(child, injectNextSibling || null);
                        }
                    } else if (inject) {
                        return $return(options.templateContent.replace(PRERENDER_REG, result || ''));
                    }
                    serialized = dom.serialize();
                    if (!/^<!DOCTYPE /mi.test(serialized)) {
                        serialized = "<!DOCTYPE html>" + serialized;
                    }
                    return $return(serialized);
                }
                
                return $If_2.call(this);
            } catch ($boundEx) {
                return $error($boundEx);
            }
        }).bind(this), $error);
    });
}

module.exports = PrerenderLoader;
//# sourceMappingURL=prerender-loader.js.map
