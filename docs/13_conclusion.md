# 13. Conclusion

The Warranty Management and Service Engine tracks every serial-numbered unit from sale to service and enforces warranty, recall and workflow rules inside the database rather than in application code. MySQL holds the 21 relational tables, and the business rules are implemented with constraints, 15 triggers, 7 stored procedures, 3 functions, 5 views, indexes, full-text search and a scheduled event. Multi-step operations such as a sale with its warranty, or a unit replacement that touches six tables, run as transactions that either complete fully or leave no trace, which the tests confirm.

PostgreSQL with pgvector adds semantic search over service requests. Complaints are embedded with the free all-MiniLM-L6-v2 model and searched by cosine distance through an HNSW index, so a technician sees how similar problems were fixed before even when the wording is completely different. All eight vector test cases found the correct past request in the top three results.

The Next.js application connects both databases through API routes, reads credentials from environment variables, and uses bcrypt passwords with signed session tokens for four roles. In total 45 database tests, 8 vector tests and the application test cases pass.

Possible extensions are sending real email or SMS for recall notices, a mobile view for technicians, and using the similarity scores to suggest likely spare parts before a repair starts.
