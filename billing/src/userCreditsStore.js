function getUserCreditsRef(db, companyId, userKey) {
	return db
		.collection("companies")
		.doc(companyId)
		.collection("users")
		.doc(userKey)
		.collection("billing")
		.doc("main");
}

module.exports = {
	getUserCreditsRef,
};
