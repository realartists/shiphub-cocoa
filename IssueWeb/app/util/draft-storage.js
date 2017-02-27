class MemoryStorage {
  constructor() {
    this.entries = {};
  }
  
  getItem(key) {
    return this.entries[key];
  }
  
  setItem(key, value) {
    this.entries[key] = value;
  }
  
  removeItem(key) {
    delete this.entries[key];
  }
}

var storage = new MemoryStorage();
// var storage = window.localStorage;

function draftKey(owner, repo, num, commentIdentifier) {
  if (!owner || !repo || !num) return null;
  
  commentIdentifier = commentIdentifier || "new";
  
  var key = `${owner}/${repo}#${num}.CommentDraft.${commentIdentifier}`;
  return key;
}

export function storeCommentDraft(owner, repo, num, commentIdentifier, draft) {
  var key = draftKey(owner, repo, num, commentIdentifier);
  if (!key) return;

  if (draft == null || draft.trim().length == 0) {
    storage.removeItem(key);
  } else {
    try {
      storage.setItem(key, draft);
    } catch (ex) {
      window.console.log("LocalStorage is full :/", ex);
    }
  }
}

export function clearCommentDraft(owner, repo, num, commentIdentifier) {
  var key = draftKey(owner, repo, num, commentIdentifier);
  if (!key) return;
  
  storage.removeItem(key);
}

export function getCommentDraft(owner, repo, num, commentIdentifier) {
  var key = draftKey(owner, repo, num, commentIdentifier);
  if (!key) return null;
  
  var draft = storage.getItem(key);
  return draft;
}

