function findTaskItems(body) {
  var lines = body.split("\n");
  var lastLineIdx = lines.length - 1;
  lines = lines.map((l, i) => {
    return i != lastLineIdx ? l+"\n" : l
  });
  
  var offset = 0;
  var tasks = [];
  
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var pattern = /^(\s*)(?:(?:\d+\.)|(?:\-)|(?:\*))\s+\[[x ]\].*(\n|$)/;
    var match = line.match(pattern);

    if (match) {
      var last = !line.endsWith("\n");
      var task = {
        start: offset,
        indent: match[1],
        end: offset + line.length,
        last: last
      };
      
      offset += line.length;
      
      // continue consuming lines as long as they have a greater indent than task
      for (var j = i+1; j < lines.length; j++) {
        var linePattern = /^([ \t]*)(.*?)(\n|$)/
        var lineMatch = lines[j].match(linePattern);
        if (lineMatch && lineMatch[1].length > task.indent.length) {
          i++;
          offset += lines[j].length;
          task.end += lines[j].length;
          task.last = !lines[j].endsWith("\n");
        } else {
          break;
        }
      }
      
      tasks.push(task);
    } else {
      offset += line.length;
    }
  }
  
  // filter tasks that are subsumed by parent tasks
  // (i.e. an earlier task's range contains them).
  
  var inRange = Array(body.length).fill(false);
  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i];
    for (var j = t.start; j < t.end; j++) {
      if (inRange[j]) {
        console.log("subsumed", t);
        t.subsumed = true;
        break;
      } else {
        inRange[j] = true;
      }
    }
  }
  
  tasks = tasks.filter((t) => !t.subsumed);
  
  return tasks;
}

export function rewriteTaskList(body, srcIdx, dstIdx) {
  // normalize newlines
  body = body.replace(/\r\n/g, '\n');
  body = body.replace(/\r/g, '\n');

  var tasks = findTaskItems(body);

  function last(task) {
    return task.last;
  }

  if (srcIdx != dstIdx && srcIdx < tasks.length && dstIdx < tasks.length) {
    var hadTrailingNewline = body.endsWith("\n");
    var src = tasks[srcIdx];
    var dst = tasks[dstIdx];
    
    var withoutSrc = body.slice(0, src.start) + body.slice(src.end);
    
    var insertionPoint = dst.start;
    if (srcIdx < dstIdx) {
      insertionPoint += ((dst.end-dst.start) - (src.end-src.start));
    }
    
    var insertion = body.slice(src.start, src.end);
    var head = withoutSrc.slice(0, insertionPoint);
    var tail = withoutSrc.slice(insertionPoint);

    if (last(src)) {
      insertion += "\n";
      tail = tail.slice(0, tail.length-1);
    } else if (last(dst)) {
      insertion = "\n" + insertion.slice(0, insertion.length-1);
    }
    
    body = head + insertion + tail;
    var hasTrailingNewline = body.endsWith("\n");
    
  }
  
  return body;
}

// Some unit tests that can be run under node.
// Flip test to use them.
if (false) {
  var failures = 0;
  var success = 0;
  
  function test(body, srcIdx, dstIdx, expected, description) {
    var result = rewriteTaskList(body, srcIdx, dstIdx);
    if (result != expected) {
      failures++;
      console.error("------------\n" +
                    "Failed " + description + "\n" +
                    "Src:\n" + body + "\n" +
                    "SrcIdx: " + srcIdx + " dstIdx: " + dstIdx + " \n" +
                    "Expected:\n" + expected + "\n" +
                    "Got:\n" + result + "\n------------\n");
    } else {
      success++;
    }
  }
  
  test(
"- [x] Complete\n" +
"- [ ] Incomplete",
      0, 1,
"- [ ] Incomplete\n" +
"- [x] Complete",
      "Swap 2"
  );
  
  test(
"- [x] Complete\n" +
"- [ ] Incomplete",
      1, 0,
"- [ ] Incomplete\n" +
"- [x] Complete",
      "Swap 2 (b)"
  );

  test(
"- [ ] 1\n" + 
"- [ ] 2\n" + 
"- [ ] 3\n" +
"- [ ] 4",
      0, 3,
"- [ ] 2\n" + 
"- [ ] 3\n" + 
"- [ ] 4\n" +
"- [ ] 1",
      "Move 4"
  );
  
  test(
"- [ ] 1\n" + 
"- [ ] 2\n" + 
"- [ ] 3\n" +
"- [ ] 4",
      3, 0,
"- [ ] 4\n" + 
"- [ ] 1\n" + 
"- [ ] 2\n" +
"- [ ] 3",
      "Move 4 (b)"
  );
  
  test(
"- [ ] 1\n" + 
"- [ ] 2\n" + 
"- [ ] 3\n" +
"- [ ] 4",
      0, 2,
"- [ ] 2\n" + 
"- [ ] 3\n" + 
"- [ ] 1\n" +
"- [ ] 4",
      "Swap 4 (c)"
  );
  
  test(
"- [ ] 1\n" + 
"- [ ] 2\n" + 
"- [ ] 3\n" +
"- [ ] 4",
      1, 2,
"- [ ] 1\n" + 
"- [ ] 3\n" + 
"- [ ] 2\n" +
"- [ ] 4",
      "Swap 4 (d)"
  );
  
  test(
" - [ ] 1\n" +
" - [ ] 2\n" +
" - [ ] 3\n" +
" - [ ] 4\n\n" +
"Extra text",
      0, 3,
" - [ ] 2\n" +
" - [ ] 3\n" +
" - [ ] 4\n" +
" - [ ] 1\n\n" +
"Extra text",
      "Leading sp, trailing text"
  );
  
  test(
"# Some prefix stuff here\n\n" +
"- [ ] 1\n" + 
"- [ ] 2\n" + 
"- [ ] 3\n" +
"- [ ] 4\n\n" +
"## Some suffix stuff here",
      0, 3,
"# Some prefix stuff here\n\n" +
"- [ ] 2\n" + 
"- [ ] 3\n" + 
"- [ ] 4\n" +
"- [ ] 1\n\n" +
"## Some suffix stuff here",
      "Prefix/suffix"
  );
  
  test(
"- [ ] 1\n" +
"  - [ ] 1.1\n" +
"  - [ ] 1.2\n" +
"- [ ] 2\n",
  0, 1,
"- [ ] 2\n" +
"- [ ] 1\n" +
"  - [ ] 1.1\n" +
"  - [ ] 1.2\n",
  "Nested list"
  );
  
  test(
"- [ ] Merge to master\n" +
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin\n" +
"- [ ] Disable beta.realartists.com\n",
  1, 0,
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Merge to master\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin\n" +
"- [ ] Disable beta.realartists.com\n",
  "Big nested list"
  );
  
  test(
"- [ ] Merge to master\n" +
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin\n" +
"- [ ] Disable beta.realartists.com\n",
  4, 3,
"- [ ] Merge to master\n" +
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Disable beta.realartists.com\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin\n",
  "Big nested list (b)"
  );
  
  test(
"- [ ] Merge to master\n" +
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Disable beta.realartists.com\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin",
  3, 4,
"- [ ] Merge to master\n" +
"- [ ] Deploy site `bash deploy.sh`\n" +
"- [ ] Apply rewrite rules to S3 bucket (rewrites.xml in Ship.Web)\n" +
"- [ ] Change Cloudfront distribution to use S3 as http proxy\n" +
"  - [ ] Add origin using the full us-west-1 URL for the S3 http hosting\n" +
"  - [ ] Change behavior to point to new origin\n" +
"  - [ ] Delete old origin\n" +
"- [ ] Disable beta.realartists.com",
  "Big nested list (c)"
  );
  
  test(
"- [x] A\r" +
"- [x] B\r" + 
"- [x] C\r" +
"- [x] D\r" +
"- [x] E\r" +
"- [x] F\r" +
"- [x] G\r" +
"- [x] H\r" +
"- [x] I\r" +
"- [x] J",
0, 9,
"- [x] B\n" + 
"- [x] C\n" +
"- [x] D\n" +
"- [x] E\n" +
"- [x] F\n" +
"- [x] G\n" +
"- [x] H\n" +
"- [x] I\n" +
"- [x] J\n" +
"- [x] A",
  "Line Endings"
  );

  console.log("" +
    (success+failures) + " tests complete. " + 
    success + " success. " + 
    failures + " failures."
  );
}
