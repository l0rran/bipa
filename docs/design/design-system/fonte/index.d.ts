// Bipa: tipos do bundle (documentação). Os componentes são markup + enhance(el).

/** Ações em pílula. Markup: <button class="bipa-btn bipa-btn--primary"> com .bipa-btn__label, .bipa-btn__spinner e .bipa-btn__done. */
/** Seletor segmentado: `.bipa-segmented` com botões `[data-value]`; dispara `bipa:select` com `{ value }`. */
export interface SegmentedProps {
  value: string;
  options: { value: string; label: string }[];
  variant?: 'default' | 'camera';
}

export interface ButtonProps {
  variant: 'primary' | 'secondary' | 'tonal';
  label: string;
  disabled?: boolean;
}

/** Etiqueta de preço. Markup: .bipa-tag (+ --hero) com .bipa-tag__value[data-cents]. */
export interface PriceTagProps {
  cents: number;
  regularCents?: number;
  hero?: boolean;
}

/**
 * Item da lista de estoque (.bipa-shelf__item). Em repouso mostra miniatura, nome e o medidor de nível;
 * tocar abre o editor com −/+ e "Pôr na lista". Emite "bipa:change" e "bipa:list".
 */
export interface StockStepperProps {
  name: string;
  place: string;
  value: number;
  /** Abaixo ou igual a este valor o item está acabando (quantidade em âmbar, "2 de 4"). */
  /** "Ter sempre": abaixo dele o item está acabando e o medidor fica âmbar. */
  min?: number;
  unit?: string;
  place?: string;
  photo?: string;
  onList?: boolean;
  open?: boolean;
}

/** Filtro de uma escolha (chips ou categorias com arte). Emite "bipa:filter" { value }. */
export interface FilterChipsProps {
  options: { value: string; label: string; count?: number; icon?: string }[];
  value: string;
  variant?: 'chips' | 'tiles';
  target?: string;
}

/** Busca com o botão de bipar dentro. Emite "bipa:scan". */
export interface SearchBarProps {
  placeholder?: string;
}

/** Prévia da lista na Casa: quantidade, total estimado, miniaturas e "Ir às compras". */
export interface ListPreviewProps {
  count: number;
  estimateCents: number;
  thumbs: { photo?: string; icon?: string }[];
}

/** Barra da compra em andamento, fixa acima da navegação. */
export interface ShoppingBarProps {
  market: string;
  done: number;
  total: number;
  cents: number;
}

/** Cartão da prateleira Acabando: imagem, medidor e "+". Emite "bipa:list" { onList }. */
export interface ProductCardProps {
  name: string;
  value: number;
  min?: number;
  unit?: string;
  photo?: string;
  onList?: boolean;
}

/** Linha que se desliza: esquerda "Usei um", direita "Pôr na lista". Emite "bipa:swipe". */
export interface SwipeRowProps {
  onUsed?: () => void;
  onList?: () => void;
}

/** Visor da câmera com trava no código e clarão de captura. Emite "bipa:captured". */
export interface ScanFrameProps {
  loop?: boolean;
  code?: string;
}

/** Bandeja do modo carrinho com total do que vai levar. */
export interface ScanTrayProps {
  items: Array<{ name: string; cents: number; take?: boolean }>;
}

/** Cartão de insight: hora de repor ou economia do mês. Emite "bipa:dismiss". */
export interface InsightCardProps {
  variant: 'restock' | 'saving';
  why: string;
}

/** Adicionar rápido e lista por corredor com progresso. */
export interface ShoppingListProps {
  market?: string;
}

/** Chip de mercado. .bipa-chip--here quando o usuário está no mercado. */
export interface MarketChipProps {
  name: string;
  distance?: string;
  here?: boolean;
}

/** Barra de navegação com indicador deslizante e botão de bipar. */
export interface ScanNavBarProps {
  active: 'casa' | 'produtos' | 'mercados' | 'lista';
}

/** Feedback de sucesso ao salvar um preço. */
export interface BipFeedbackProps {
  price: string;
  market: string;
}

/** Placeholder de carregamento com brilho. */
export interface SkeletonProps {
  width: string;
  height: string;
}

export interface BipaEnhancer {
  enhance(el: HTMLElement, options?: Record<string, unknown>): void;
}

export interface BipaNamespace {
  version: string;
  formatCents(cents: number): string;
  roll(el: HTMLElement, text: string | number, direction?: 'up' | 'down'): void;
  countUp(el: HTMLElement, cents: number, duration?: number): void;
  tweenCents(el: HTMLElement, from: number, to: number, duration?: number): void;
  Button: BipaEnhancer;
  Segmented: BipaEnhancer;
  PriceTag: BipaEnhancer & { play(tag: HTMLElement): void };
  StockStepper: BipaEnhancer;
  FilterChips: BipaEnhancer;
  ProductCard: BipaEnhancer;
  Carousel: BipaEnhancer;
  SearchBar: BipaEnhancer;
  ShoppingBar: { enhance(el: HTMLElement): { update(state: { done: number; total: number; cents?: number }): void } };
  SwipeRow: BipaEnhancer;
  MarketChip: BipaEnhancer;
  ScanNavBar: BipaEnhancer;
  BipFeedback: BipaEnhancer & { play(el: HTMLElement): void };
  Skeleton: BipaEnhancer;
  ScanFrame: { enhance(el: HTMLElement, options?: ScanFrameProps): { search(): void; lock(code?: string): void } };
  ScanTray: { enhance(el: HTMLElement): { add(item: { name: string; cents: number }): void } };
  InsightCard: BipaEnhancer;
  ShoppingList: BipaEnhancer;
}

declare global {
  interface Window {
    Bipa: BipaNamespace;
  }
}
