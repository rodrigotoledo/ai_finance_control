class TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]

  def index
    @transactions = current_user.transactions.order(created_at: :desc)
  end

  def show
  end

  def new
    @transaction = current_user.transactions.build
  end

  def create
    @transaction = current_user.transactions.build(transaction_params)

    if @transaction.save
      redirect_to @transaction, notice: "Transaction created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_url, notice: "Transaction deleted successfully"
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :category, :date)
  end
end
