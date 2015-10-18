define("ace/mode/gitignore_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],function(a,b){"use strict";var c=a("../lib/oop"),d=a("./text_highlight_rules").TextHighlightRules,e=function(){this.$rules={start:[{token:"comment",regex:/^\s*#.*$/},{token:"keyword",regex:/^\s*!.*$/}]},this.normalizeRules()};e.metaData={fileTypes:["gitignore"],name:"Gitignore"},c.inherits(e,d),b.GitignoreHighlightRules=e}),define("ace/mode/gitignore",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/gitignore_highlight_rules"],function(a,b){"use strict";var c=a("../lib/oop"),d=a("./text").Mode,e=a("./gitignore_highlight_rules").GitignoreHighlightRules,f=function(){this.HighlightRules=e};c.inherits(f,d),function(){this.lineCommentStart="#",this.$id="ace/mode/gitignore"}.call(f.prototype),b.Mode=f});