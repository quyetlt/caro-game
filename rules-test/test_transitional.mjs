import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, collection, setDoc, getDoc, getDocs, updateDoc, serverTimestamp,
} from 'firebase/firestore';
import { readFileSync } from 'fs';

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-caro',
  firestore: {
    rules: readFileSync('firestore.transitional.rules', 'utf8'),
    host: '127.0.0.1', port: 8080,
  },
});

let pass = 0, fail = 0;
async function check(name, ok, op) {
  try { await (ok ? assertSucceeds(op()) : assertFails(op())); console.log(`  ✓ ${name}`); pass++; }
  catch (e) { console.log(`  ✗ ${name}\n      ${String(e).split('\n')[0]}`); fail++; }
}

const alice = testEnv.authenticatedContext('alice').firestore();
const carol = testEnv.authenticatedContext('carol').firestore();

await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/bob'), { displayName: 'Bob', friendCode: 'BBB222' });
  await setDoc(doc(db, 'friendCodes/DDD444'), { uid: 'bob', displayName: 'Bob' });
  await setDoc(doc(db, 'matches/m_turnO'), {
    mode: 'random', roomCode: null, status: 'playing',
    hostUid: 'alice', hostName: 'Alice', guestUid: 'bob', guestName: 'Bob',
    moves: [], turn: 'O', winner: null, createdAt: serverTimestamp(),
  });
});

console.log('\n[chuyển tiếp] kiểm tra tương thích ngược + bảo mật vẫn còn');
// /users mở lại (để app cũ kết bạn bằng query hoạt động)
await check('người lạ ĐỌC được users (tạm mở)', true, () => getDoc(doc(carol, 'users/bob')));
await check('query toàn bộ users hoạt động (app cũ)', true, () => getDocs(collection(carol, 'users')));
// friendCodes (app mới) vẫn dùng được
await check('tra cứu friendCodes hoạt động', true, () => getDoc(doc(alice, 'friendCodes/DDD444')));
// matches anti-cheat vẫn thực thi
await check('đánh sai lượt vẫn bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_turnO'), { moves: [{ r: 0, c: 0, p: 'X' }], turn: 'O' }));
await check('người lạ đọc ván đang chơi vẫn bị chặn', false, () => getDoc(doc(carol, 'matches/m_turnO')));

await testEnv.cleanup();
console.log(`\nKẾT QUẢ: ${pass} pass, ${fail} fail`);
process.exit(fail === 0 ? 0 : 1);
