-- Columna para guardar el ID de transacción de Wompi (evita duplicados)
ALTER TABLE wallet_transactions
  ADD COLUMN IF NOT EXISTS wompi_transaction_id text;

CREATE UNIQUE INDEX IF NOT EXISTS wallet_transactions_wompi_tx_id_idx
  ON wallet_transactions (wompi_transaction_id)
  WHERE wompi_transaction_id IS NOT NULL;

-- RPC que acredita saldo al usuario de forma atómica
CREATE OR REPLACE FUNCTION credit_wallet(p_user_id uuid, p_amount numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET wallet_balance = COALESCE(wallet_balance, 0) + p_amount
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id;
  END IF;
END;
$$;
