-- -- Copyright (c) 2017 Scott Morrison. All rights reserved.
-- -- Released under Apache 2.0 license as described in the file LICENSE.
-- -- Authors: Scott Morrison

-- import .if_then_else
-- import .hash_target

-- open tactic
-- open nat

-- -- FIXME can we set options? It's annoying to have to pass a configuration everywhere.

-- structure chain_cfg := 
--   ( max_steps     : nat  := 500 )
--   ( trace_steps   : bool := ff )
--   ( fail_on_loop  : bool := tt )
--   ( trace_on_loop : bool := tt )
--   ( allowed_collisions : nat  := 0 )

-- private meta structure chain_progress { α : Type } :=
--   ( iteration_limit   : nat )
--   ( results           : list α )
--   ( remaining_tactics : list (tactic α) )
--   ( hashes            : list string )
--   ( repeats           : nat )

-- -- TODO
-- -- it would be lovely to pull out all the looping detection code, and implement that by wrapping
-- -- tactics in suitable state monads, but I don't think we're ready for that yet!
-- private meta def chain'
--   { α : Type } [ has_to_format α ] 
--   ( cfg : chain_cfg )
--   ( tactics : list (tactic α) ) 
--     : chain_progress → tactic (list α)
-- | ⟨ 0,      results, _, hashes, _ ⟩ := trace (format!"... chain tactic exceeded iteration limit {cfg.max_steps}") >>
--                                         trace results.reverse >> 
--                                         failed   
-- | ⟨ _,      results, [], _, _ ⟩     := (pure results)
-- | ⟨ succ n, results, t :: ts, hashes, repeats ⟩ :=
--     if_then_else done
--       (pure results)
--       (do if cfg.trace_steps then trace format!"trying chain tactic #{tactics.length - ts.length}" else skip,
--           some r ← try_core t | /- tactic t failed, continue down the list -/ (chain' ⟨ succ n, results, ts, hashes, repeats ⟩),
--           h ← hash_target,
--           let repeat := if hashes.mem h then 1 else 0 in
--           if (repeat = 1) && (repeats ≥ cfg.allowed_collisions) then 
--             /- we've run into a loop -/
--             do if cfg.trace_on_loop then trace "chain tactic detected looping" else skip,
--                if cfg.fail_on_loop then
--                  trace results.reverse >> fail "chain tactic detected looping"
--                else 
--                  /- continue down the list -/
--                  (chain' ⟨ succ n, results, ts, hashes, repeats + repeat ⟩)
--           else 
--             do (if cfg.trace_steps then trace format!"succeeded with result: {r}" else skip),  
--                 (chain' ⟨ n, r :: results, tactics, h :: hashes, repeats + repeat ⟩ )
--       )

-- meta def chain { α : Type } [ has_to_format α ] 
--   ( tactics        : list (tactic α) )
--   ( cfg     : chain_cfg := {} )
--     : tactic (list α) :=
-- do sequence ← chain' cfg tactics ⟨ cfg.max_steps, [], tactics, [], 0 ⟩,
--    guard (sequence.length ≠ 0) <|> fail "...chain tactic made no progress",
--    pure sequence.reverse