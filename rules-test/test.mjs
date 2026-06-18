import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  query,
  where,
  serverTimestamp,
} from 'firebase/firestore';
import { readFileSync } from 'fs';

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-caro',
  firestore: {
    rules: readFileSync('firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

let pass = 0;
let fail = 0;
async function check(name, shouldSucceed, op) {
  try {
    await (shouldSucceed ? assertSucceeds(op()) : assertFails(op()));
    console.log(`  ✓ ${name}`);
    pass++;
  } catch (e) {
    console.log(`  ✗ ${name}\n      ${String(e).split('\n')[0]}`);
    fail++;
  }
}

const alice = testEnv.authenticatedContext('alice').firestore();
const bob = testEnv.authenticatedContext('bob').firestore();
const carol = testEnv.authenticatedContext('carol').firestore();

// ---- Seed dữ liệu (bỏ qua rules) ----
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/alice'), { displayName: 'Alice', friendCode: 'AAA111' });
  await setDoc(doc(db, 'users/bob'), { displayName: 'Bob', friendCode: 'BBB222' });
  // bob coi alice là bạn (kết bạn 2 chiều)
  await setDoc(doc(db, 'users/bob/friends/alice'), { name: 'Alice' });
  await setDoc(doc(db, 'users/alice/friends/bob'), { name: 'Bob' });

  await setDoc(doc(db, 'friendCodes/CCC333'), { uid: 'alice', displayName: 'Alice' });
  await setDoc(doc(db, 'friendCodes/DDD444'), { uid: 'bob', displayName: 'Bob' });

  // Ván đang chơi (host=alice X, guest=bob O), một doc riêng cho mỗi kịch bản
  // ghi để các test không ảnh hưởng lẫn nhau.
  const playing = (extra = {}) => ({
    mode: 'random', roomCode: null, status: 'playing',
    hostUid: 'alice', hostName: 'Alice', guestUid: 'bob', guestName: 'Bob',
    moves: [], turn: 'X', winner: null,
    rematchHost: false, rematchGuest: false, createdAt: serverTimestamp(),
    ...extra,
  });
  for (const id of ['m_read', 'm_valid', 'm_two', 'm_oppsym', 'm_host', 'm_stranger', 'm_leave']) {
    await setDoc(doc(db, `matches/${id}`), playing());
  }
  await setDoc(doc(db, 'matches/m_turnO'), playing({ turn: 'O' }));
  // Ván đã có 1 quân, để thử ghi đè quân cũ (cùng kích thước).
  await setDoc(doc(db, 'matches/m_overwrite'), playing({ moves: [{ r: 0, c: 0, p: 'X' }], turn: 'O' }));
  // Ván đang chờ (chưa có guest)
  await setDoc(doc(db, 'matches/waiting'), {
    mode: 'room', roomCode: 'ROOM01', status: 'waiting',
    hostUid: 'alice', hostName: 'Alice', guestUid: null, guestName: null,
    moves: [], turn: 'X', winner: null,
    rematchHost: false, rematchGuest: false, createdAt: serverTimestamp(),
  });
});

console.log('\n[users] đọc hồ sơ');
await check('self đọc hồ sơ của mình', true, () => getDoc(doc(alice, 'users/alice')));
await check('bạn bè đọc được hồ sơ', true, () => getDoc(doc(alice, 'users/bob')));
await check('người lạ KHÔNG đọc được', false, () => getDoc(doc(carol, 'users/bob')));
await check('liệt kê toàn bộ users bị chặn', false, () => getDocs(collection(alice, 'users')));

console.log('\n[friendCodes] tra cứu mã');
await check('đọc bằng mã chính xác', true, () => getDoc(doc(alice, 'friendCodes/DDD444')));
await check('liệt kê toàn bộ friendCodes bị chặn', false, () => getDocs(collection(alice, 'friendCodes')));
await check('tạo mã trỏ về chính mình', true, () => setDoc(doc(bob, 'friendCodes/NEW999'), { uid: 'bob', displayName: 'Bob' }));
await check('tạo mã trỏ về người khác bị chặn', false, () => setDoc(doc(alice, 'friendCodes/HACK1'), { uid: 'bob', displayName: 'x' }));
await check('sửa mã của mình', true, () => updateDoc(doc(alice, 'friendCodes/CCC333'), { displayName: 'Alice2' }));
await check('chiếm mã của người khác bị chặn', false, () => updateDoc(doc(alice, 'friendCodes/DDD444'), { uid: 'alice' }));

console.log('\n[matches] đọc ván');
await check('người trong ván đọc ván đang chơi', true, () => getDoc(doc(alice, 'matches/m_read')));
await check('người lạ KHÔNG đọc ván đang chơi', false, () => getDoc(doc(carol, 'matches/m_read')));
await check('ai cũng đọc được ván đang chờ', true, () => getDoc(doc(carol, 'matches/waiting')));
await check('query ván đang chờ (ghép trận)', true, () =>
  getDocs(query(collection(carol, 'matches'), where('status', '==', 'waiting'))));
await check('liệt kê toàn bộ matches bị chặn', false, () => getDocs(collection(carol, 'matches')));

console.log('\n[matches] chống gian lận khi đánh');
await check('host đánh đúng lượt của mình', true, () =>
  updateDoc(doc(alice, 'matches/m_valid'), {
    moves: [{ r: 0, c: 0, p: 'X' }], turn: 'O', winner: null,
    status: 'playing', turnStartedAt: serverTimestamp(),
  }));
await check('host đánh khi tới lượt đối thủ bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_turnO'), {
    moves: [{ r: 0, c: 0, p: 'X' }], turn: 'O', status: 'playing',
  }));
await check('đặt 2 quân một lúc bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_two'), {
    moves: [{ r: 0, c: 0, p: 'X' }, { r: 1, c: 1, p: 'X' }], turn: 'O', status: 'playing',
  }));
await check('đánh bằng ký hiệu của đối thủ bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_oppsym'), {
    moves: [{ r: 0, c: 0, p: 'O' }], turn: 'O', status: 'playing',
  }));
await check('ghi đè quân cũ (tráo bàn) bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_overwrite'), {
    moves: [{ r: 5, c: 5, p: 'O' }], status: 'abandoned',
  }));
await check('đổi hostUid bị chặn', false, () =>
  updateDoc(doc(alice, 'matches/m_host'), { hostUid: 'carol' }));
await check('người lạ cập nhật ván bị chặn', false, () =>
  updateDoc(doc(carol, 'matches/m_stranger'), { status: 'abandoned' }));
await check('host rời ván (đầu hàng) hợp lệ', true, () =>
  updateDoc(doc(alice, 'matches/m_leave'), { status: 'abandoned' }));

console.log('\n[matches] tham gia ván chờ');
await check('người mới vào làm guest hợp lệ', true, () =>
  updateDoc(doc(bob, 'matches/waiting'), {
    guestUid: 'bob', guestName: 'Bob', status: 'playing', turnStartedAt: serverTimestamp(),
  }));

await testEnv.cleanup();
console.log(`\nKẾT QUẢ: ${pass} pass, ${fail} fail`);
process.exit(fail === 0 ? 0 : 1);
