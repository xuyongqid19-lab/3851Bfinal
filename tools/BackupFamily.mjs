// Run with the Family Node runtime. Copies a consistent SQLite snapshot, including WAL.
import {DatabaseSync,backup} from 'node:sqlite';
import {existsSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
const [input,output]=process.argv.slice(2);
if(!input||!output)throw new Error('Usage: node tools/BackupFamily.mjs <existing.sqlite> <new-backup.sqlite>');
const source=resolve(input),destination=resolve(output);
if(source===destination||!existsSync(source)||existsSync(destination))throw new Error('Use an existing source and a new destination; existing files are never overwritten.');
mkdirSync(dirname(destination),{recursive:true});
const db=new DatabaseSync(source,{readOnly:true});
try{await backup(db,destination);console.log('Family database snapshot saved. Stop Family before restoring a backup.');}finally{db.close();}
