--- Sixfold Deck
--- A standard 52-card deck that lets you play and discard up to 6 cards per hand,
--- with new 6-card poker hands, a planet card for each, a ×Mult bonus that grows
--- every time one of those hands is played, and a cash-out bonus for each one.
--- The new hands, their planets, and the stricter Straight Flush rule only apply to runs
--- using this deck; other decks play exactly as before.

local SIXFOLD_LIMIT = 6

-- Newer Steamodded builds track play/discard limits separately and expose helpers for them.
-- Older builds (e.g. 1.0.0~BETA-0509c) don't, so we fall back to patching the vanilla limits.
local HAS_SMODS_LIMITS = (SMODS.change_play_limit ~= nil and SMODS.change_discard_limit ~= nil)

-- True while a run using this deck is in progress. The flag lives in G.GAME so it is
-- saved with the run and survives "Continue".
local function sixfold_active()
    return G.GAME and G.GAME.sixf_limit ~= nil
end

-- Set of the new 6-card hands' keys ({ ['sixf_three_pair'] = true, ... }).
-- Declared here so the deck can use it; filled in by add_hand further down.
local SIX_HAND_KEYS = {}

-- ×Mult gained per new 6-card hand played.
local XMULT_GAIN = 0.1

-- Dollars paid at cash-out for each new 6-card hand played that round.
local MONEY_PER_SIX = 2

-- Current scaling bonus: X1 plus the gain for every 6-card hand played this run.
-- Rounded to 2 decimals so floating-point noise (1.3000000000000003) never reaches the screen.
local function sixfold_xmult()
    local raw = 1 + XMULT_GAIN * ((G.GAME and G.GAME.sixf_six_hands) or 0)
    return math.floor(raw * 100 + 0.5) / 100
end

---------------------------------------------------------------------------------------------
-- On-screen ×Mult badge, shown just above the draw pile during Sixfold runs
---------------------------------------------------------------------------------------------

-- true:  the badge glides to stay centred over the whole draw pile as it thins out.
-- false: the badge stays fixed, centred on the top card (which never moves).
local BADGE_FOLLOWS_PILE = true

-- The badge text reads from this table, so updating `text` updates the screen.
local XMULT_BADGE = { text = 'X1' }

-- The badge's offset from its anchor. The UIBox keeps a reference to this exact table,
-- so changing x here moves the badge.
local BADGE_OFFSET = { x = 0, y = -0.15 }
local badge_follow_x = 0   -- smoothed horizontal shift, in game units

-- How far the badge may lean, in game units (a card is about 2 units wide). Dragging the
-- deck's top card stretches the "pile", so the badge leans toward it; these limits keep it
-- from tucking under the shop panel on the left or sliding off the screen on the right.
local BADGE_LEAN_LEFT, BADGE_LEAN_RIGHT = -0.6, 1.5

-- How far the pile's visual centre is from the deck spot's centre (which the badge is
-- anchored to). The top card sits on the deck's spot; the cards beneath it are drawn
-- shifted down-right to show thickness, so the pile as a whole extends to the right.
-- Measured from the cards' actual positions, so it doesn't matter which card is on top.
local function pile_centre_shift()
    local deck, cards = G.deck, G.deck and G.deck.cards
    if not (deck and deck.T and cards and #cards > 0) then return 0 end
    local left, right = math.huge, -math.huge
    for _, card in ipairs(cards) do
        if card.T then
            left = math.min(left, card.T.x)
            right = math.max(right, card.T.x + card.T.w)
        end
    end
    if left == math.huge then return 0 end
    local shift = (left + right) / 2 - (deck.T.x + deck.T.w / 2)
    return math.max(BADGE_LEAN_LEFT, math.min(BADGE_LEAN_RIGHT, shift))
end

local function apply_badge_offset(x)
    local badge = G.sixf_xmult_badge
    if not badge then return end
    BADGE_OFFSET.x = x
    if badge.alignment and badge.alignment.offset then badge.alignment.offset.x = x end
    badge.NEW_ALIGNMENT = true
    if badge.align_to_major then badge:align_to_major() end
end

-- Called every frame: ease the badge toward the pile's centre.
local function update_badge_position(dt)
    if not (BADGE_FOLLOWS_PILE and G.sixf_xmult_badge) then return end
    local target = pile_centre_shift()
    badge_follow_x = badge_follow_x + (target - badge_follow_x) * math.min(1, (dt or 0) * 6)
    apply_badge_offset(badge_follow_x)
end

local function set_badge_value(value)
    XMULT_BADGE.text = 'X' .. string.format('%g', value)
end

local function remove_xmult_badge()
    if G.sixf_xmult_badge then
        G.sixf_xmult_badge:remove()
        G.sixf_xmult_badge = nil
    end
end

local function create_xmult_badge()
    remove_xmult_badge()
    if not (sixfold_active() and G.deck) then return end
    set_badge_value(sixfold_xmult())
    G.sixf_xmult_badge = UIBox {
        definition = { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.06, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = {
                { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                    { n = G.UIT.T, config = { text = '6-card hands', scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
                } },
                { n = G.UIT.R, config = { align = 'cm', padding = 0.04, r = 0.08, minw = 0.95, colour = G.C.MULT }, nodes = {
                    { n = G.UIT.O, config = { object = DynaText({
                        string = { { ref_table = XMULT_BADGE, ref_value = 'text' } },
                        colours = { G.C.WHITE }, scale = 0.42, shadow = true,
                    }) } },
                } },
            } },
        } },
        -- 'tm' = sits above the deck (outside it); the deck's card count stays visible below.
        config = { align = 'tm', offset = BADGE_OFFSET, major = G.deck },
    }
    -- Start already in position, so the badge doesn't slide in at the start of a run.
    badge_follow_x = BADGE_FOLLOWS_PILE and pile_centre_shift() or 0
    apply_badge_offset(badge_follow_x)
end

---------------------------------------------------------------------------------------------
-- Cash-out bonus: MONEY_PER_SIX dollars for each new 6-card hand played this round
---------------------------------------------------------------------------------------------
-- Two ways to pay it, depending on the Steamodded version:
--   * Newer Steamodded asks each deck for a dollar bonus at cash-out (the deck's
--     calc_dollar_bonus, defined on the deck below) and shows it as its own line.
--   * Older versions (e.g. 1.0.0~BETA-0509c) don't, so we patch add_round_eval_row (below).
-- Both take from the same per-round count, which is emptied when paid, so the bonus is paid
-- exactly once whichever runs: on newer versions the deck pays first and the patch finds
-- nothing left to pay.

-- Takes this round's 6-card hand count, leaving 0 behind.
local function take_round_six_hands()
    local count = (G.GAME and G.GAME.sixf_round_six_hands) or 0
    if G.GAME then G.GAME.sixf_round_six_hands = 0 end
    return count
end

local function cashout_label(count)
    return '6-Card Hands x' .. count .. ' ($' .. MONEY_PER_SIX .. ' each)'
end

-- Older-version patch: the game builds the cash-out screen one line at a time and finishes
-- with the total ('bottom'). Just before the total, we add our own line and fold its dollars
-- into the total. Our line reuses the game's joker-payout line style (an orange label, like
-- Golden Joker's). That style looks up a name for the line's card, so we give it a stand-in
-- "card" whose name entry we write ourselves, and which makes the x-Mult badge bounce.

local CASHOUT_LABEL_KEY = 'sixf_cashout'

local CASHOUT_CARD = {
    config = { center = { set = 'Other', key = CASHOUT_LABEL_KEY } },
    juice_up = function(self, ...)
        if G.sixf_xmult_badge then G.sixf_xmult_badge:juice_up(...) end
    end,
}

local function set_cashout_label(count)
    local descriptions = G.localization and G.localization.descriptions
    if not descriptions then return end
    descriptions.Other = descriptions.Other or {}
    descriptions.Other[CASHOUT_LABEL_KEY] = {
        name = cashout_label(count),
        text = {},
    }
end

local add_round_eval_row_ref = add_round_eval_row
function add_round_eval_row(config)
    if config and config.name == 'bottom' and sixfold_active() then
        local count = take_round_six_hands()
        if count > 0 then
            local bonus = count * MONEY_PER_SIX
            set_cashout_label(count)
            add_round_eval_row_ref({
                dollars = bonus, bonus = true, pitch = 1.1,
                name = 'sixf_joker_bonus',  -- 'joker' in the name selects the joker line style
                card = CASHOUT_CARD,
            })
            config.dollars = (config.dollars or 0) + bonus
        end
    end
    return add_round_eval_row_ref(config)
end

local game_update_ref = Game.update
function Game:update(dt)
    game_update_ref(self, dt)
    update_badge_position(dt)
end

---------------------------------------------------------------------------------------------
-- Deck
---------------------------------------------------------------------------------------------

-- Card back art: assets/1x/backs.png and assets/2x/backs.png (one 71x95 slot).
-- Steamodded prefixes both this key and the deck's atlas = 'backs' with 'sixf_', so they match.
SMODS.Atlas {
    key = 'backs',
    path = 'backs.png',
    px = 71,
    py = 95,
}

SMODS.Back {
    key = 'sixfold',
    loc_txt = {
        name = 'Sixfold Deck',
        text = {
            'Play and discard up to {C:attention}#1#{} cards',
            'Each {C:attention}6-card hand{} played gives',
            '{X:mult,C:white} X#2# {} Mult to 6-card hands',
            'and {C:money}$#3#{} at end of round',
            '{C:red}#4#{} hand every round',
        },
        -- The current X-Mult value isn't listed here: the badge above the deck shows it live.
    },
    -- `hands` is a standard deck setting (the Black Deck uses the same one): the game
    -- applies it to the hands per round at the start of the run.
    config = { card_limit = SIXFOLD_LIMIT, xmult_gain = XMULT_GAIN, money_per_six = MONEY_PER_SIX, hands = -1 },

    atlas = 'backs',
    pos = { x = 0, y = 0 },

    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, back)
        return { vars = { self.config.card_limit, self.config.xmult_gain, self.config.money_per_six, self.config.hands } }
    end,

    -- Scaling bonus. final_scoring_step runs once per scored hand, after jokers (the same
    -- step the Plasma Deck uses), so the bonus multiplies the hand's full Mult.
    calculate = function(self, back, context)
        if not context.final_scoring_step then return end
        local hand = context.scoring_name or G.GAME.last_hand_played
        if not SIX_HAND_KEYS[hand] then return end

        -- Count this hand first, so the hand that earns the upgrade also gets it.
        G.GAME.sixf_six_hands = (G.GAME.sixf_six_hands or 0) + 1
        G.GAME.sixf_round_six_hands = (G.GAME.sixf_round_six_hands or 0) + 1  -- paid at cash-out
        local value = sixfold_xmult()

        -- Update the on-screen badge as a queued event, so it changes in step with the
        -- scoring animation (just before the "Upgrade!" pop-up) rather than instantly.
        G.E_MANAGER:add_event(Event({
            func = function()
                set_badge_value(value)
                if G.sixf_xmult_badge then G.sixf_xmult_badge:juice_up(0.3, 0.3) end
                return true
            end,
        }))

        return {
            message = localize('k_upgrade_ex'),
            colour = G.C.MULT,
            xmult = value,
        }
    end,

    -- Cash-out bonus on newer Steamodded, which calls this at cash-out and shows the amount
    -- as its own line with this label. (See the cash-out section above for older versions.)
    calc_dollar_bonus = function(self, back)
        local count = take_round_six_hands()
        if count > 0 then
            return count * MONEY_PER_SIX, { text = cashout_label(count) }
        end
    end,

    apply = function(self, back)
        local target = self.config.card_limit
        G.GAME.sixf_limit = target
        G.GAME.sixf_six_hands = 0
        G.GAME.sixf_round_six_hands = 0

        if HAS_SMODS_LIMITS then
            -- Deferred to an event so the hand area exists before the limits are changed.
            G.E_MANAGER:add_event(Event({
                func = function()
                    local play_diff = target - (G.GAME.starting_params.play_limit or 5)
                    local discard_diff = target - (G.GAME.starting_params.discard_limit or 5)
                    if play_diff ~= 0 then SMODS.change_play_limit(play_diff) end
                    if discard_diff ~= 0 then SMODS.change_discard_limit(discard_diff) end
                    return true
                end,
            }))
        end
        -- Without the helpers, the hooks at the bottom of this file handle everything.
    end,
}

---------------------------------------------------------------------------------------------
-- Hand-detection helpers
---------------------------------------------------------------------------------------------

-- Rank of a card (2-14, Ace = 14), or nil for rankless cards such as Stone Cards.
local function card_rank(card)
    local id = card:get_id()
    if id and id > 0 then return id end
end

local function suit_list()
    return (SMODS.Suit and SMODS.Suit.obj_buffer) or { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }
end

local function merge(groups)
    local out = {}
    for _, group in ipairs(groups) do
        for _, card in ipairs(group) do out[#out + 1] = card end
    end
    return out
end

-- Cards grouped by rank, largest group first. One group per distinct rank.
local function rank_groups(hand)
    local by_rank = {}
    for _, card in ipairs(hand) do
        local r = card_rank(card)
        if r then
            by_rank[r] = by_rank[r] or {}
            table.insert(by_rank[r], card)
        end
    end
    local groups = {}
    for _, cards in pairs(by_rank) do groups[#groups + 1] = cards end
    table.sort(groups, function(a, b) return #a > #b end)
    return groups
end

-- Groups with at least n cards.
local function groups_of_at_least(groups, n)
    local out = {}
    for _, group in ipairs(groups) do
        if #group >= n then out[#out + 1] = group end
    end
    return out
end

-- Cards counting as the given suit for flushes (Wild Cards count, Stone Cards don't).
local function cards_of_suit(hand, suit)
    local out = {}
    for _, card in ipairs(hand) do
        if card:is_suit(suit, nil, true) then out[#out + 1] = card end
    end
    return out
end

-- The first suit with at least n cards, returned as that list of cards, or nil.
local function flush_of(hand, n)
    for _, suit in ipairs(suit_list()) do
        local cards = cards_of_suit(hand, suit)
        if #cards >= n then return cards end
    end
end

-- Finds a run of at least `length` consecutive ranks and returns the cards in it, or nil.
-- Ace plays high or low (no wrap-around, as in vanilla). The Shortcut joker allows
-- gaps of one rank, as it does for vanilla straights.
local function find_straight(hand, length)
    local shortcut = next(find_joker('Shortcut'))
    local by_rank = {}
    for _, card in ipairs(hand) do
        local r = card_rank(card)
        if r then
            by_rank[r] = by_rank[r] or {}
            table.insert(by_rank[r], card)
        end
    end
    by_rank[1] = by_rank[14] -- Ace low

    for start = 1, 14 do
        if by_rank[start] then
            local chain, current = { start }, start
            while true do
                local nxt
                if by_rank[current + 1] then
                    nxt = current + 1
                elseif shortcut and by_rank[current + 2] then
                    nxt = current + 2
                end
                if not nxt then break end
                chain[#chain + 1] = nxt
                current = nxt
            end
            if #chain >= length then
                local out, seen = {}, {}
                for _, r in ipairs(chain) do
                    for _, card in ipairs(by_rank[r]) do
                        if not seen[card] then
                            seen[card] = true
                            out[#out + 1] = card
                        end
                    end
                end
                return out
            end
        end
    end
end

-- A straight made entirely of cards of one suit, or nil.
local function find_straight_flush(hand, length)
    for _, suit in ipairs(suit_list()) do
        local suited = cards_of_suit(hand, suit)
        if #suited >= length then
            local run = find_straight(suited, length)
            if run then return run end
        end
    end
end

-- Wraps a detector so the hand only exists in Sixfold runs.
-- SMODS expects a list of scoring-card groups back; an empty table means "not present".
local function sixfold_hand(detect)
    return function(parts, hand)
        if not sixfold_active() then return {} end
        local cards = detect(hand)
        if cards and #cards > 0 then return { cards } end
        return {}
    end
end

---------------------------------------------------------------------------------------------
-- Stricter Straight Flush (Sixfold runs only)
---------------------------------------------------------------------------------------------
-- Vanilla counts any hand that contains a straight AND a flush as a Straight Flush, even
-- when they use different cards. With 6 cards that happens about 6x as often as a true
-- straight flush, so in Sixfold runs the straight must be made of the flush's cards.
-- Four Fingers still lets it be 4 cards long, as in vanilla.

local vanilla_straight_flush = SMODS.PokerHands and SMODS.PokerHands['Straight Flush']
if vanilla_straight_flush then
    local original_evaluate = vanilla_straight_flush.evaluate
    vanilla_straight_flush.evaluate = function(parts, hand)
        if not sixfold_active() then return original_evaluate(parts, hand) end
        local length = next(find_joker('Four Fingers')) and 4 or 5
        local cards = find_straight_flush(hand, length)
        if cards then return { cards } end
        return {}
    end
end

---------------------------------------------------------------------------------------------
-- New 6-card hands
---------------------------------------------------------------------------------------------
-- `above_hand` slots each hand into the ranking directly above the named hand.
-- Order, weakest to strongest (vanilla hands in brackets):
--   [Flush] Three Pair [Full House] Long Straight, Big Flush [Four of a Kind]
--   Double Trips, Mansion [Straight Flush] Long Straight Flush
--   [Five of a Kind] [Flush House] [Flush Five] Six of a Kind, Flush Mansion, Flush Six
-- Four Fingers does not shorten the new 6-card hands; Shortcut does allow gaps in them.

local new_hands = {} -- { key = <prefixed key>, secret = bool }

local function add_hand(def, secret)
    def.visible = not secret
    local obj = SMODS.PokerHand(def)
    -- Steamodded adds the mod prefix to the key ('three_pair' -> 'sixf_three_pair').
    local key = (obj and obj.key) or ('sixf_' .. def.key)
    new_hands[#new_hands + 1] = { key = key, secret = secret }
    SIX_HAND_KEYS[key] = true
    return key
end

local three_pair = add_hand({
    key = 'three_pair',
    above_hand = 'Flush',
    chips = 35, mult = 4, l_chips = 20, l_mult = 2,
    loc_txt = { name = 'Three Pair', description = { '3 pairs of cards with', 'different ranks' } },
    example = {
        { 'S_A', true }, { 'H_A', true }, { 'D_K', true },
        { 'C_K', true }, { 'H_7', true }, { 'S_7', true },
    },
    evaluate = sixfold_hand(function(hand)
        local pairs_ = groups_of_at_least(rank_groups(hand), 2)
        if #pairs_ >= 3 then return merge({ pairs_[1], pairs_[2], pairs_[3] }) end
    end),
})

local long_straight = add_hand({
    key = 'long_straight',
    above_hand = 'Full House',
    chips = 50, mult = 5, l_chips = 30, l_mult = 3,
    loc_txt = { name = 'Long Straight', description = { '6 cards in a row', '(consecutive ranks)' } },
    example = {
        { 'S_9', true }, { 'H_8', true }, { 'D_7', true },
        { 'C_6', true }, { 'H_5', true }, { 'S_4', true },
    },
    evaluate = sixfold_hand(function(hand)
        return find_straight(hand, 6)
    end),
})

local big_flush = add_hand({
    key = 'big_flush',
    above_hand = long_straight,
    chips = 55, mult = 5, l_chips = 30, l_mult = 3,
    loc_txt = { name = 'Big Flush', description = { '6 cards that share', 'the same suit' } },
    example = {
        { 'H_A', true }, { 'H_J', true }, { 'H_9', true },
        { 'H_6', true }, { 'H_4', true }, { 'H_2', true },
    },
    evaluate = sixfold_hand(function(hand)
        return flush_of(hand, 6)
    end),
})

local two_triples = add_hand({
    key = 'two_triples',
    above_hand = 'Four of a Kind',
    chips = 70, mult = 7, l_chips = 35, l_mult = 3,
    loc_txt = { name = 'Double Trips', description = { '2 sets of 3 cards', 'with different ranks' } },
    example = {
        { 'S_9', true }, { 'H_9', true }, { 'D_9', true },
        { 'C_4', true }, { 'H_4', true }, { 'S_4', true },
    },
    evaluate = sixfold_hand(function(hand)
        local triples = groups_of_at_least(rank_groups(hand), 3)
        if #triples >= 2 then return merge({ triples[1], triples[2] }) end
    end),
})

local fuller_house = add_hand({
    key = 'fuller_house',
    above_hand = two_triples,
    chips = 80, mult = 8, l_chips = 35, l_mult = 3,
    loc_txt = { name = 'Mansion', description = { 'A Four of a Kind and', 'a Pair of another rank' } },
    example = {
        { 'S_Q', true }, { 'H_Q', true }, { 'D_Q', true },
        { 'C_Q', true }, { 'H_3', true }, { 'S_3', true },
    },
    evaluate = sixfold_hand(function(hand)
        local groups = rank_groups(hand)
        if groups[1] and groups[2] and #groups[1] >= 4 and #groups[2] >= 2 then
            return merge({ groups[1], groups[2] })
        end
    end),
})

local long_straight_flush = add_hand({
    key = 'long_straight_flush',
    above_hand = 'Straight Flush',
    chips = 120, mult = 10, l_chips = 45, l_mult = 4,
    loc_txt = { name = 'Long Straight Flush', description = { '6 cards in a row', 'all of the same suit' } },
    example = {
        { 'D_T', true }, { 'D_9', true }, { 'D_8', true },
        { 'D_7', true }, { 'D_6', true }, { 'D_5', true },
    },
    evaluate = sixfold_hand(function(hand)
        return find_straight_flush(hand, 6)
    end),
})

-- Secret hands: hidden until played, like Five of a Kind. Need duplicate cards.

local six_of_a_kind = add_hand({
    key = 'six_of_a_kind',
    above_hand = 'Flush Five',
    chips = 180, mult = 18, l_chips = 55, l_mult = 4,
    loc_txt = { name = 'Six of a Kind', description = { '6 cards with the same rank' } },
    example = {
        { 'S_8', true }, { 'H_8', true }, { 'D_8', true },
        { 'C_8', true }, { 'S_8', true }, { 'H_8', true },
    },
    evaluate = sixfold_hand(function(hand)
        local groups = rank_groups(hand)
        if groups[1] and #groups[1] >= 6 then return groups[1] end
    end),
}, true)

local flusher_house = add_hand({
    key = 'flusher_house',
    above_hand = six_of_a_kind,
    chips = 200, mult = 20, l_chips = 60, l_mult = 4,
    loc_txt = { name = 'Flush Mansion', description = { 'A Four of a Kind and a Pair', 'with all cards sharing', 'the same suit' } },
    example = {
        { 'S_J', true }, { 'S_J', true }, { 'S_J', true },
        { 'S_J', true }, { 'S_5', true }, { 'S_5', true },
    },
    evaluate = sixfold_hand(function(hand)
        local groups = rank_groups(hand)
        if groups[1] and groups[2] and #groups[1] >= 4 and #groups[2] >= 2 then
            local cards = merge({ groups[1], groups[2] })
            if flush_of(cards, 6) then return cards end
        end
    end),
}, true)

local flush_six = add_hand({
    key = 'flush_six',
    above_hand = flusher_house,
    chips = 220, mult = 22, l_chips = 65, l_mult = 4,
    loc_txt = { name = 'Flush Six', description = { '6 cards with the same', 'rank and suit' } },
    example = {
        { 'H_K', true }, { 'H_K', true }, { 'H_K', true },
        { 'H_K', true }, { 'H_K', true }, { 'H_K', true },
    },
    evaluate = sixfold_hand(function(hand)
        local groups = rank_groups(hand)
        if groups[1] and #groups[1] >= 6 and flush_of(groups[1], 6) then return groups[1] end
    end),
}, true)

---------------------------------------------------------------------------------------------
-- Planets (placeholder names and art)
---------------------------------------------------------------------------------------------
-- Regular hands get moons; secret hands get dwarf planets, like vanilla's Planet X / Ceres / Eris.
-- Art: assets/1x/planets.png and assets/2x/planets.png, one row of 71x95 cards.
-- Steamodded prefixes both this atlas key and the planets' atlas = 'planets' with 'sixf_',
-- so they match each other.

SMODS.Atlas {
    key = 'planets',
    path = 'planets.png',
    px = 71,
    py = 95,
}

local function add_planet(key, name, hand_key, art_x, secret)
    SMODS.Consumable {
        set = 'Planet',
        key = key,
        atlas = 'planets',
        pos = { x = art_x, y = 0 },
        config = { hand_type = hand_key },
        cost = 3,
        unlocked = true,
        discovered = true,
        loc_txt = {
            name = name,
            text = {
                '{S:0.8}({S:0.8}lvl.#1#{S:0.8}){} Level up',
                '{C:attention}#2#',
                '{C:mult}+#3#{} Mult and',
                '{C:chips}+#4#{} chips',
            },
        },
        loc_vars = function(self, info_queue, card)
            local hand = G.GAME and G.GAME.hands and G.GAME.hands[hand_key]
            return { vars = {
                hand and hand.level or 1,
                localize(hand_key, 'poker_hands'),
                hand and hand.l_mult or 0,
                hand and hand.l_chips or 0,
            } }
        end,
        in_pool = function(self, args)
            if not sixfold_active() then return false end
            if secret then
                local hand = G.GAME.hands[hand_key]
                return hand ~= nil and (hand.played or 0) > 0
            end
            return true
        end,
    }
end

add_planet('io',       'Io',       three_pair,          0)
add_planet('europa',   'Europa',   long_straight,       1)
add_planet('ganymede', 'Ganymede', big_flush,           2)
add_planet('callisto', 'Callisto', two_triples,         3)
add_planet('titan',    'Titan',    fuller_house,        4)
add_planet('triton',   'Triton',   long_straight_flush, 5)
add_planet('haumea',   'Haumea',   six_of_a_kind,       6, true)
add_planet('makemake', 'Makemake', flusher_house,       7, true)
add_planet('sedna',    'Sedna',    flush_six,           8, true)

---------------------------------------------------------------------------------------------
-- Vanilla joker upgrades for 6-card hands (Sixfold runs only)
---------------------------------------------------------------------------------------------
-- take_ownership lets us add to a vanilla joker. Our calculate runs first; returning nothing
-- hands control back to the vanilla effect, so outside Sixfold runs (and for ordinary hands)
-- these jokers behave exactly as normal. The `true` at the end keeps the jokers from showing
-- a mod badge. Each one also gets an extra tooltip in Sixfold runs, explaining the upgrade
-- (text in localization/en-us.lua).

local function in_sixfold_run()
    return G.STAGE == G.STAGES.RUN and sixfold_active()
end

local function contains(context, hand_key)
    return context.poker_hands and next(context.poker_hands[hand_key] or {}) ~= nil
end

local function has_consumable_room(n)
    return #G.consumeables.cards + G.GAME.consumeable_buffer + n <= G.consumeables.config.card_limit
end

-- Create n consumables of a set (as vanilla does: reserve room now, create in an event).
local function create_consumables(set, n, seed)
    G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + n
    G.E_MANAGER:add_event(Event({
        func = function()
            for _ = 1, n do
                local c = create_card(set, G.consumeables, nil, nil, nil, nil, nil, seed)
                c:add_to_deck()
                G.consumeables:emplace(c)
            end
            G.GAME.consumeable_buffer = 0
            return true
        end,
    }))
end

local function sixfold_tooltip(tooltip_key)
    return function(self, info_queue, card)
        if in_sixfold_run() then
            info_queue[#info_queue + 1] = { key = tooltip_key, set = 'Other' }
        end
        -- No vars returned, so the joker's own text keeps its usual numbers.
    end
end

-- Superposition: a Long Straight containing an Ace creates 2 Tarots instead of 1.
-- If there's only room for one, the vanilla effect makes the usual single Tarot.
SMODS.Joker:take_ownership('superposition', {
    loc_vars = sixfold_tooltip('sixf_superposition'),
    calculate = function(self, card, context)
        if not (context.joker_main and sixfold_active() and contains(context, long_straight)) then return end
        local has_ace = false
        for _, c in ipairs(context.scoring_hand or {}) do
            if c:get_id() == 14 then has_ace = true end
        end
        if not (has_ace and has_consumable_room(2)) then return end
        create_consumables('Tarot', 2, 'sup')
        return { message = '+2 Tarot', colour = G.C.SECONDARY_SET.Tarot }
    end,
}, true)

-- Custom sounds in assets/sounds/. Steamodded adds the mod prefix to each key, so they
-- play as 'sixf_seance_intro', 'sixf_seance_2' and 'sixf_seance_3'.
SMODS.Sound { key = 'seance_intro', path = 'seance_intro.ogg' }
SMODS.Sound { key = 'seance_2',     path = 'seance_2.ogg' }
SMODS.Sound { key = 'seance_3',     path = 'seance_3.ogg' }

-- Timing, in real seconds (unaffected by the game speed setting).
local SEANCE_INTRO_FALLBACK = 1.0  -- used only if seance_intro.ogg's length can't be measured
local SEANCE_CARD_GAP       = 0.5  -- pause between the first and second Spectral card
local SEANCE_VOLUME         = 0.7

-- How long scoring waits for the intro: the real length of seance_intro.ogg, so a
-- replacement file of any length lines up without code changes. Steamodded keeps each
-- loaded sound's file data, which LÖVE can decode to read its duration. Measured once, the
-- first time it's needed; if anything about that fails, the fallback above is used.
local seance_intro_length_cache
local function seance_intro_length()
    if seance_intro_length_cache then return seance_intro_length_cache end
    local length
    local sound = SMODS.Sounds and SMODS.Sounds['sixf_seance_intro']
    if sound and sound.data and love and love.sound and love.sound.newDecoder then
        local ok, decoder = pcall(love.sound.newDecoder, sound.data)
        if ok and decoder then
            local ok2, duration = pcall(decoder.getDuration, decoder)
            if ok2 and type(duration) == 'number' and duration > 0 then length = duration end
        end
    end
    seance_intro_length_cache = length or SEANCE_INTRO_FALLBACK
    return seance_intro_length_cache
end

-- Queue a pause that holds up everything queued after it (scoring included).
local function wait_real(seconds)
    G.E_MANAGER:add_event(Event({
        trigger = 'after', delay = seconds, timer = 'REAL',
        func = function() return true end,
    }))
end

-- Queue: create one card of a set, then play the given sounds together.
local function create_one_with_sounds(set, seed, sounds)
    G.E_MANAGER:add_event(Event({
        func = function()
            local c = create_card(set, G.consumeables, nil, nil, nil, nil, nil, seed)
            c:add_to_deck()
            G.consumeables:emplace(c)
            for _, s in ipairs(sounds) do play_sound(s, 1, SEANCE_VOLUME) end
            return true
        end,
    }))
end

-- Seance: a Long Straight Flush creates 2 Spectrals instead of 1, with a little ceremony:
--   1. When the hand is played (cards in the centre, before scoring): seance_intro plays,
--      and scoring waits until it finishes.
--   2. First Spectral appears with seance_2 + seance_3 together.
--   3. A short pause, then the second Spectral appears with seance_3 again.
SMODS.Joker:take_ownership('seance', {
    loc_vars = sixfold_tooltip('sixf_seance'),
    calculate = function(self, card, context)
        if not (sixfold_active() and contains(context, long_straight_flush)) then return end

        -- Step 1, before scoring. Room for both cards is reserved now, so another joker
        -- creating a card mid-hand can't leave the ceremony without room to finish.
        if context.before and not context.blueprint then
            if not has_consumable_room(2) then return end
            G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 2
            card.ability.sixf_seance_armed = true
            G.E_MANAGER:add_event(Event({
                func = function()
                    play_sound('sixf_seance_intro', 1, SEANCE_VOLUME)
                    return true
                end,
            }))
            wait_real(seance_intro_length())
            return  -- nothing else happens here; vanilla Seance has no "before" effect
        end

        if not context.joker_main then return end

        -- Steps 2 and 3: the original Seance, armed in step 1.
        if card.ability.sixf_seance_armed and not context.blueprint then
            card.ability.sixf_seance_armed = nil
            create_one_with_sounds('Spectral', 'sea', { 'sixf_seance_2', 'sixf_seance_3' })
            wait_real(SEANCE_CARD_GAP)
            create_one_with_sounds('Spectral', 'sea', { 'sixf_seance_3' })
            G.E_MANAGER:add_event(Event({
                func = function() G.GAME.consumeable_buffer = 0; return true end,
            }))
            return { message = '+2 Spectral', colour = G.C.SECONDARY_SET.Spectral }
        end

        -- Blueprint/Brainstorm copies: 2 Spectrals, quietly, if there's room.
        if has_consumable_room(2) then
            create_consumables('Spectral', 2, 'sea')
            return { message = '+2 Spectral', colour = G.C.SECONDARY_SET.Spectral }
        end
    end,
}, true)

-- Runner: a hand containing a Long Straight upgrades it twice (+30 Chips instead of +15).
-- Blueprint copies don't upgrade, same as vanilla.
SMODS.Joker:take_ownership('runner', {
    loc_vars = sixfold_tooltip('sixf_runner'),
    calculate = function(self, card, context)
        if not (context.before and not context.blueprint and sixfold_active()
                and contains(context, long_straight)) then return end
        local extra = card.ability.extra
        extra.chips = extra.chips + extra.chip_mod * 2
        return { message = localize('k_upgrade_ex'), colour = G.C.CHIPS }
    end,
}, true)

-- Spare Trousers: a hand containing Three Pair upgrades it twice (+4 Mult instead of +2).
SMODS.Joker:take_ownership('trousers', {
    loc_vars = sixfold_tooltip('sixf_trousers'),
    calculate = function(self, card, context)
        if not (context.before and not context.blueprint and sixfold_active()
                and contains(context, three_pair)) then return end
        card.ability.mult = card.ability.mult + card.ability.extra * 2
        return { message = localize('k_upgrade_ex'), colour = G.C.RED }
    end,
}, true)

-- Faceless Joker: discarding 6 face cards at once earns $12 instead of $5.
-- (Pareidolia makes every card a face card, so it counts any 6.)
-- Vanilla Faceless pays during the discard itself, once, as the last discarded card is
-- processed. We step in at that same moment: returning our payout there replaces the
-- vanilla $5 rather than adding to it.
local FACELESS_SIX_DOLLARS = 12
SMODS.Joker:take_ownership('faceless', {
    loc_vars = sixfold_tooltip('sixf_faceless'),
    calculate = function(self, card, context)
        if not (context.discard and sixfold_active()) then return end
        local hand = context.full_hand or {}
        if context.other_card ~= hand[#hand] then return end  -- only on the last card
        local faces = 0
        for _, c in ipairs(context.full_hand or {}) do
            if c:is_face() then faces = faces + 1 end
        end
        if faces < 6 then return end
        return { dollars = FACELESS_SIX_DOLLARS }
    end,
}, true)

-- To Do List: when its target is one of the new 6-card hands, it pays double ($8).
-- Rather than replacing its payout, we keep its own dollar value in sync with the target,
-- so the vanilla effect pays the right amount and its description shows it ("Earn $8").
SMODS.Joker:take_ownership('todo_list', {
    loc_vars = sixfold_tooltip('sixf_todo_list'),
}, true)

local function sync_todo_list(card)
    local ability = card.ability
    if not (ability and ability.name == 'To Do List' and type(ability.extra) == 'table'
            and type(ability.extra.dollars) == 'number') then return end
    ability.extra.sixf_base = ability.extra.sixf_base or ability.extra.dollars
    local double = sixfold_active() and SIX_HAND_KEYS[ability.to_do_poker_hand]
    ability.extra.dollars = double and ability.extra.sixf_base * 2 or ability.extra.sixf_base
end

local card_update_ref = Card.update
function Card:update(dt)
    card_update_ref(self, dt)
    sync_todo_list(self)
end

---------------------------------------------------------------------------------------------
-- Run-start hooks
---------------------------------------------------------------------------------------------

local start_run_ref = Game.start_run
function Game:start_run(args)
    start_run_ref(self, args)

    -- A new run (any deck) clears the previous run's badge; Sixfold runs get a fresh one,
    -- including continued runs, which read the saved bonus.
    create_xmult_badge()

    if sixfold_active() then
        -- Make sure the hand lets you select 6. Older Steamodded: vanilla creates the hand
        -- with a limit of 5, so this is what raises it. Newer Steamodded: the limit is saved
        -- with the run and restored, so this is only a safety net.
        if G.hand then
            local params = G.GAME.starting_params or {}
            G.hand.config.highlighted_limit = math.max(
                G.hand.config.highlighted_limit or 5, G.GAME.sixf_limit,
                params.play_limit or 0, params.discard_limit or 0)
        end
    elseif G.GAME and G.GAME.hands then
        -- Other decks: keep the new hands out of Run Info.
        for _, h in ipairs(new_hands) do
            if G.GAME.hands[h.key] then G.GAME.hands[h.key].visible = false end
        end
    end
end

if not HAS_SMODS_LIMITS then
    -- Play button: vanilla greys it out when more than 5 cards are selected.
    local can_play_ref = G.FUNCS.can_play
    G.FUNCS.can_play = function(e)
        can_play_ref(e)
        if sixfold_active() then
            local n = #G.hand.highlighted
            if n > 0 and n <= G.GAME.sixf_limit and not G.GAME.blind.block_play then
                e.config.colour = G.C.BLUE
                e.config.button = 'play_cards_from_highlighted'
            end
        end
    end
    -- The vanilla discard button has no 5-card cap, so the raised selection limit is enough for it.
end
