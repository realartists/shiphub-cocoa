import 'whatwg-fetch'
import {encode as b64ArrayBufferEncode } from 'base64-arraybuffer'

var endpoint = "https://86qvuywske.execute-api.us-east-1.amazonaws.com/prod/shiphub-attachments";

var maxFileSize = 10 * 1024 * 1024; /* 10 MB */

/* Takes a File object and returns a promise to upload it, which itself resolves
   to either a URL where the file now lives or an error.
*/
export default function uploadAttachment(token, file) {
  if (file.size > maxFileSize) {
    return new Promise((resolve, reject) => {
      reject(`File ${file.name} is larger than ${maxFileSize / (1024*1024)}MB and cannot be uploaded`);
    });
  }

  var readPromise = new Promise((resolve, reject) => {
    var reader = new FileReader();
    reader.onload = (e) => {
      resolve(reader.result);
    }
    reader.onerror = (e) => {
      reject(e);
    }
    reader.readAsArrayBuffer(file);
  });
  
  return readPromise.then((fileArrayBuffer) => {
    var body = {
      token: token,
      filename: file.name || "file",
      fileMime: file.type,
      file: b64ArrayBufferEncode(fileArrayBuffer)
    };
    
    console.log("Putting attachment", body);
    return new Promise((resolve, reject) => {
      var f = fetch(endpoint, { 
        headers:{"Content-Type": "application/json"}, 
        method: "PUT",
        body: JSON.stringify(body)
      });
      
      f.then((resp) => {
        return resp.json();
      }).then((json) => {
        if (json.url) {
          resolve(json.url)
        } else {
          console.log("unexpected response from server", json);
          reject("Unexpected response from server");
        }
      }).catch((err) => {
        reject(err);
      });
    });
  });
}
