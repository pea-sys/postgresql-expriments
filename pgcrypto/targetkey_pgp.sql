select pgp_sym_encrypt('data','password');
                                                                pgp_sym_encrypt      
------------------------------------------------------------------------------------------------------------------------------------------------
 \xc30d04070302e6e4fd9d1fa25c6567d23501e6a3ef8e74fa1d3a12c22ac0b98eb2cff18743f058d2111c8a0b4c9f6ea2b24211c54a92d9822922d179b8f54c396a2534dcfa6e
(1 行)


select pgp_sym_decrypt(pgp_sym_encrypt('data','password'),'password');
 pgp_sym_decrypt
-----------------
 data
(1 行)